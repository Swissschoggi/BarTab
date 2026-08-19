import Foundation
import CryptoKit
import Security

/// Handles Supabase Auth (GoTrue) over REST, plus the `profiles` lookup
/// used to determine whether a signed-in user is an admin.
///
/// Tokens are persisted in the Keychain via `KeychainService` so the
/// session survives app launches.
final class SupabaseAuthService {

    private let baseURL = SupabaseConfig.projectURL
    private let apiKey = SupabaseConfig.anonKey

    private let keychain = KeychainService(
        service: "com.bartab.session"
    )

    private let sessionAccount = "session"

    struct AuthUser: Codable, Identifiable {
        let id: UUID
        let email: String
        let username: String
        let createdAt: Date
    }

    struct AuthTokens: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date?
    }

    struct AuthSession: Codable {
        let user: AuthUser
        let tokens: AuthTokens
    }

    enum AuthError: LocalizedError {

        case invalidAppleToken
        case emailConfirmationRequired
        case invalidResponse
        case network(String)
        case server(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidAppleToken:
                return "The Apple identity token could not be read."

            case .emailConfirmationRequired:
                return "Check your inbox to confirm your email before signing in."

            case .invalidResponse:
                return "The server returned an unexpected response."

            case .network(let message):
                return "Could not reach the server: \(message)"

            case .server(let status, let message):
                return "Sign in failed (\(status)): \(message)"
            }
        }
    }

    // MARK: - Keychain session

    func restoreSession() -> AuthSession? {
        guard let data = keychain.read(account: sessionAccount),
              let session = try? JSONDecoder().decode(
                  AuthSession.self,
                  from: data
              ) else {
            return nil
        }

        return session
    }

    func saveSession(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        keychain.write(data, account: sessionAccount)
    }

    func clearSession() {
        keychain.delete(account: sessionAccount)
    }

    // MARK: - Auth requests

    func signUp(
        email: String,
        password: String
    ) async throws -> AuthSession {

        let body = [
            "email": email,
            "password": password
        ]

        let data = try await performAuth(
            endpoint: "signup",
            body: body
        )

        let response = try decodeSessionResponse(data)

        // Email confirmation enabled -> no tokens returned yet.
        guard let session = response.session else {
            throw AuthError.emailConfirmationRequired
        }

        return session
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> AuthSession {

        let body = [
            "email": email,
            "password": password
        ]

        let data = try await performAuth(
            endpoint: "token?grant_type=password",
            body: body
        )

        guard let session = try decodeSessionResponse(data).session else {
            throw AuthError.invalidResponse
        }

        return session
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String
    ) async throws -> AuthSession {

        let body = [
            "id_token": idToken,
            "nonce": rawNonce
        ]

        let data = try await performAuth(
            endpoint: "token?grant_type=id_token",
            body: body
        )

        guard let session = try decodeSessionResponse(data).session else {
            throw AuthError.invalidResponse
        }

        return session
    }

    func logout(accessToken: String) async throws {
        let url = baseURL
            .appendingPathComponent("auth/v1/logout")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            apiKey,
            forHTTPHeaderField: "apikey"
        )
        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        _ = try await perform(request)
    }

    // MARK: - Admin lookup

    func fetchIsAdmin(
        userID: UUID,
        accessToken: String
    ) async -> Bool {

        let endpoint =
            "profiles?select=is_admin&id=eq.\(userID.uuidString)"

        var request = URLRequest(
            url: URL(
                string: "\(baseURL.absoluteString)/rest/v1/\(endpoint)"
            )!
        )
        request.setValue(
            apiKey,
            forHTTPHeaderField: "apikey"
        )
        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        guard let data = try? await perform(request),
              let rows = try? JSONDecoder().decode(
                  [[String: Bool]].self,
                  from: data
              ) else {
            return false
        }

        return rows.first?["is_admin"] ?? false
    }

    // MARK: - Helpers

    private func performAuth(
        endpoint: String,
        body: [String: String]
    ) async throws -> Data {

        let url = URL(
            string: "\(baseURL.absoluteString)/auth/v1/\(endpoint)"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            apiKey,
            forHTTPHeaderField: "apikey"
        )
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        return try await perform(request)
    }

    private func perform(
        _ request: URLRequest
    ) async throws -> Data {

        let (data, response) = try await
            URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network("bad server response")
        }

        guard (200...299).contains(http.statusCode) else {

            let message = String(
                data: data,
                encoding: .utf8
            ) ?? "No response body"

            throw AuthError.server(
                http.statusCode,
                message
            )
        }

        return data
    }

    private func decodeSessionResponse(
        _ data: Data
    ) throws -> SessionResponse {

        let decoder = JSONDecoder()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = formatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Invalid ISO8601 date: \(string)"
            )
        }

        return try decoder.decode(
            SessionResponse.self,
            from: data
        )
    }

    private struct SessionResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: GoTrueUser

        var session: AuthSession? {
            guard let access = access_token else {
                return nil
            }

            let createdAt: Date

            if let createdString = user.created_at,
               let date = SupabaseAuthService
                   .parseISODate(createdString) {
                createdAt = date
            } else {
                createdAt = Date()
            }

            let email = user.email ?? ""

            let username: String

            if let fromMetadata = user.user_metadata?["username"],
               !fromMetadata.isEmpty {
                username = fromMetadata
            } else if !email.isEmpty {
                username = email.components(
                    separatedBy: "@"
                ).first ?? email
            } else {
                username = "BarTab User"
            }

            let expiresAt: Date?

            if let expiresIn = expires_in {
                expiresAt = Date().addingTimeInterval(
                    TimeInterval(expiresIn)
                )
            } else {
                expiresAt = nil
            }

            return AuthSession(
                user: AuthUser(
                    id: user.id,
                    email: email,
                    username: username,
                    createdAt: createdAt
                ),
                tokens: AuthTokens(
                    accessToken: access,
                    refreshToken: refresh_token ?? "",
                    expiresAt: expiresAt
                )
            )
        }
    }

    private struct GoTrueUser: Decodable {
        let id: UUID
        let email: String?
        let user_metadata: [String: String]?
        let created_at: String?
    }

    // MARK: - Nonce helpers (used by Sign in with Apple)

    static func randomNonceString(
        length: Int = 32
    ) -> String {

        let charset =
            Array(
                "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ"
                + "abcdefghijklmnopqrstuvwxyz-._"
            )

        var result = ""
        var remaining = length

        while remaining > 0 {

            var random = [UInt8](repeating: 0, count: 16)

            _ = SecRandomCopyBytes(
                kSecRandomDefault,
                random.count,
                &random
            )

            for byte in random where remaining > 0 {

                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {

        let digest = SHA256.hash(
            data: Data(input.utf8)
        )

        return digest.map {
            String(format: "%02x", $0)
        }.joined()
    }

    /// Parses GoTrue timestamps, which may or may not include
    /// fractional seconds.
    private static func parseISODate(
        _ string: String
    ) -> Date? {

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = fractional.date(from: string) {
            return date
        }

        let standard = ISO8601DateFormatter()
        return standard.date(from: string)
    }
}