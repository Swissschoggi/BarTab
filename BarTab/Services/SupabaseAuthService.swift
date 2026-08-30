import Foundation
import CryptoKit
import Security

/// Handles Supabase Auth (GoTrue) over REST, plus the `profiles` lookup
/// used to determine a signed-in user's display name, admin status and
/// avatar.
///
/// Tokens are persisted in the Keychain via `KeychainService` so the
/// session survives app launches. Access tokens expire after roughly
/// one hour, so restoring a session transparently refreshes it using
/// the stored refresh token.
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

    struct ProfileInfo {
        let username: String
        let isAdmin: Bool
        let avatarURL: URL?
    }

    enum AuthError: LocalizedError {

        case invalidAppleToken
        case emailConfirmationRequired
        case invalidResponse
        case invalidCallbackURL
        case oauthCancelled
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

            case .invalidCallbackURL:
                return "Google sign-in could not be completed. Please try again."

            case .oauthCancelled:
                return nil

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
            AuthTokenStore.shared.clear()
            return nil
        }

        mirrorTokens(from: session)
        return session
    }

    func saveSession(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        _ = keychain.write(data, account: sessionAccount)
        mirrorTokens(from: session)
    }

    func clearSession() {
        keychain.delete(account: sessionAccount)
        AuthTokenStore.shared.clear()
    }

    /// True when the access token is missing or expires within the
    /// next 5 minutes.
    private var sessionNeedsRefresh: Bool {
        guard let tokens = restoreSession()?.tokens else {
            return false
        }

        guard let expiresAt = tokens.expiresAt else {
            return false
        }

        return Date().addingTimeInterval(300) >= expiresAt
    }

    /// Exchanges the stored refresh token for a fresh access token.
    @discardableResult
    func refreshSession() async throws -> AuthSession {

        guard let stored = restoreSession(),
              !stored.tokens.refreshToken.isEmpty else {
            throw AuthError.invalidResponse
        }

        let body = [
            "refresh_token": stored.tokens.refreshToken
        ]

        let data = try await performAuth(
            endpoint: "token?grant_type=refresh_token",
            body: body
        )

        guard let response = try decodeSessionResponse(data).session else {
            throw AuthError.invalidResponse
        }

        saveSession(response)
        return response
    }

    /// Returns a valid session, refreshing it first when needed.
    /// Returns nil when nobody is signed in or the refresh fails.
    func validSession() async -> AuthSession? {
        if sessionNeedsRefresh {
            return try? await refreshSession()
        }
        return restoreSession()
    }

    private func mirrorTokens(from session: AuthSession) {
        AuthTokenStore.shared.update(
            accessToken: session.tokens.accessToken,
            refreshToken: session.tokens.refreshToken,
            expiresAt: session.tokens.expiresAt,
            userID: session.user.id
        )
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

        saveSession(session)
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

        saveSession(session)
        return session
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String
    ) async throws -> AuthSession {

        let body = [
            "id_token": idToken,
            "nonce": rawNonce,
            "provider": "apple"
        ]

        return try await signInWithIDToken(body: body)
    }

    private func signInWithIDToken(
        body: [String: String]
    ) async throws -> AuthSession {

        let data = try await performAuth(
            endpoint: "token?grant_type=id_token",
            body: body
        )

        guard let session = try decodeSessionResponse(data).session else {
            throw AuthError.invalidResponse
        }

        saveSession(session)
        return session
    }

    func resetPassword(email: String) async throws {
        let body: [String: String] = [
            "email": email,
            "redirect_to": "bartab://reset-password"
        ]
        _ = try await performAuth(endpoint: "recover", body: body)
    }

    /// Handles the deep link redirect after a password reset.
    /// Parses access_token and refresh_token from the URL fragment
    /// and saves the new session.
    func handleResetPasswordCallback(_ url: URL) async -> Bool {
        guard url.host == "reset-password",
              let fragment = url.fragment else { return false }

        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }
            params[String(keyValue[0])] =
                String(keyValue[1]).removingPercentEncoding ?? String(keyValue[1])
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else { return false }

        do {
            let userData = try await fetchGoTrueUser(accessToken: accessToken)
            let expiresIn = Int(params["expires_in"] ?? "")
            let session = Self.makeSession(
                user: userData,
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: expiresIn
            )
            saveSession(session)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Google OAuth

    /// The Supabase authorize URL that starts the Google OAuth flow.
    /// Present it with ASWebAuthenticationSession; the browser
    /// redirects back to `<scheme>://auth/callback`.
    static func googleAuthorizeURL() -> URL? {
        var components = URLComponents(
            url: SupabaseConfig.projectURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(
                name: "redirect_to",
                value: "\(SupabaseConfig.oauthCallbackScheme)://auth/callback"
            )
        ]

        return components?.url
    }

    /// Handles the deep link returned by the Google OAuth flow.
    /// Tokens arrive in the URL fragment:
    /// `bartab://auth/callback#access_token=…&refresh_token=…&expires_in=…`
    func handleGoogleCallback(_ callbackURL: URL) async throws -> AuthSession {

        guard callbackURL.scheme == SupabaseConfig.oauthCallbackScheme else {
            throw AuthError.invalidCallbackURL
        }

        guard let fragment = callbackURL.fragment else {
            throw AuthError.invalidCallbackURL
        }

        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }
            params[String(keyValue[0])] =
                String(keyValue[1])
                    .removingPercentEncoding ?? String(keyValue[1])
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw AuthError.invalidCallbackURL
        }

        let expiresIn = Int(params["expires_in"] ?? "")
        let userData = try await fetchGoTrueUser(accessToken: accessToken)

        let session = Self.makeSession(
            user: userData,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )

        saveSession(session)
        return session
    }

    private func fetchGoTrueUser(
        accessToken: String
    ) async throws -> GoTrueUser {

        let url = baseURL.appendingPathComponent("auth/v1/user")

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        let data = try await perform(request)
        return try decodeGoTrueUser(data)
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

    // MARK: - Account updates

    func updateUsername(
        _ newUsername: String,
        accessToken: String
    ) async throws {

        let url = baseURL
            .appendingPathComponent("auth/v1/user")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
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

        let body: [String: Any] = [
            "data": ["username": newUsername]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let userData = try await perform(request)

        // Also update profiles.display_name
        if let user = try? decodeGoTrueUser(userData) {
            try? await SupabaseClient.shared.updateProfileDisplayName(
                userID: user.id,
                displayName: newUsername
            )
        }
    }

    func updatePassword(
        _ newPassword: String,
        accessToken: String
    ) async throws {

        let url = baseURL
            .appendingPathComponent("auth/v1/user")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
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

        let body: [String: Any] = [
            "password": newPassword
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await perform(request)
    }

    // MARK: - Profile lookup

    /// Reads display name, admin flag and avatar from the
    /// `profiles` table. Falls back to the email prefix when the
    /// profile row doesn't exist yet.
    func fetchProfile(
        userID: UUID,
        fallbackUsername: String
    ) async -> ProfileInfo {

        do {
            let profile = try await SupabaseClient.shared.fetchProfile(
                userID: userID
            )

            let name = profile.display_name?.isEmpty == false
                ? profile.display_name!
                : fallbackUsername

            return ProfileInfo(
                username: name,
                isAdmin: profile.is_admin,
                avatarURL: profile.avatar_url.flatMap(URL.init(string:))
            )
        } catch {
            return ProfileInfo(
                username: fallbackUsername,
                isAdmin: false,
                avatarURL: nil
            )
        }
    }

    // MARK: - Helpers

    private func performAuth(
        endpoint: String,
        body: [String: String]
    ) async throws -> Data {

        guard let url = URL(
            string: "\(baseURL.absoluteString)/auth/v1/\(endpoint)"
        ) else {
            throw AuthError.invalidResponse
        }

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
    ) throws -> (user: GoTrueUser, session: AuthSession?) {

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

        // Session shape: { access_token, refresh_token, expires_in, user }
        if let response = try? decoder.decode(
            SessionResponse.self,
            from: data
        ), response.access_token != nil {
            return (
                user: response.goTrueUser,
                session: response.session
            )
        }

        // Confirmation-required shape: the raw user object, no session.
        if let user = try? decodeGoTrueUser(data) {
            return (user: user, session: nil)
        }

        throw AuthError.invalidResponse
    }

    private func decodeGoTrueUser(
        _ data: Data
    ) throws -> GoTrueUser {

        let wrapper = try? JSONDecoder().decode(
            GoTrueUserWrapper.self,
            from: data
        )

        if let wrapper, let user = wrapper.user {
            return user
        }

        let direct = try JSONDecoder().decode(
            GoTrueUser.self,
            from: data
        )
        return direct
    }

    private static func makeSession(
        user: GoTrueUser,
        accessToken: String,
        refreshToken: String,
        expiresIn: Int?
    ) -> AuthSession {

        let createdAt: Date

        if let createdString = user.created_at,
           let date = SupabaseAuthService.parseISODate(createdString) {
            createdAt = date
        } else {
            createdAt = Date()
        }

        let email = user.email ?? ""

        let username: String

        if let metadataUsername = user.user_metadata?.username,
           !metadataUsername.isEmpty {
            username = metadataUsername
        } else if !email.isEmpty {
            username = email.components(
                separatedBy: "@"
            ).first ?? email
        } else {
            username = "BarTab User"
        }

        let expiresAt: Date?

        if let expiresIn {
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
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
        )
    }

    private struct SessionResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: ResponseUser?

        struct ResponseUser: Decodable {
            let id: UUID
            let email: String?
            let created_at: String?
            let user_metadata: UserMetadata?
        }

        struct UserMetadata: Decodable {
            let username: String?
        }

        var goTrueUser: GoTrueUser {
            GoTrueUser(
                id: user?.id ?? UUID(),
                email: user?.email,
                created_at: user?.created_at,
                user_metadata: user.map {
                    GoTrueUser.UserMetadata(
                        username: $0.user_metadata?.username
                    )
                }
            )
        }

        var session: AuthSession? {
            guard let access = access_token else {
                return nil
            }

            let createdUser = GoTrueUser(
                id: user?.id ?? UUID(),
                email: user?.email,
                created_at: user?.created_at,
                user_metadata: nil
            )

            let base = SupabaseAuthService.makeSession(
                user: createdUser,
                accessToken: access,
                refreshToken: refresh_token ?? "",
                expiresIn: expires_in
            )

            return base
        }
    }

    struct GoTrueUser: Decodable {
        let id: UUID
        let email: String?
        let created_at: String?
        let user_metadata: UserMetadata?

        struct UserMetadata: Decodable {
            let username: String?
        }
    }

    private struct GoTrueUserWrapper: Decodable {
        let user: GoTrueUser?
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
