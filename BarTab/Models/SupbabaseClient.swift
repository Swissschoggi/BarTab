import Foundation

/// Shared Supabase project credentials.
/// Replace with your project details from
/// Supabase Dashboard -> Settings -> API.
enum SupabaseConfig {

    static let projectURL = URL(
        string: "https://xdyewakhzjnmpzhzhehl.supabase.co"
    )!

    static let anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhkeWV3YWtoempubXB6aHpoZWhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwODc2MjksImV4cCI6MjEwMjY2MzYyOX0.nAZASYlhS3OBFc-mBSUVenGUTuzfMZgcbt9eBhc4Dm4"

    /// Deep-link scheme used as the OAuth redirect target
    /// (Google sign-in). Must match CFBundleURLTypes in Info.plist.
    static let oauthCallbackScheme = "bartab"
}

/// Holds the signed-in user's access token so every REST call runs
/// with the caller's identity (required once Row Level Security is
/// enabled — the anon key alone fails every `auth.uid()` check).
final class AuthTokenStore {

    static let shared = AuthTokenStore()

    private let lock = NSLock()

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var expiresAt: Date?

    private init() {}

    var hasToken: Bool {
        lock.lock()
        defer { lock.unlock() }
        return accessToken != nil
    }

    func update(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date?
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
    }
}

/// Thin Supabase REST (PostgREST + Auth + Storage) client.
///
/// The URL and anon key come from Supabase Dashboard -> Settings -> API.
/// The anon key is safe to ship in the app by design — it only unlocks
/// whatever your Row Level Security policies allow.
final class SupabaseClient {

    static let shared = SupabaseClient()

    /// Serializes token-refresh attempts so concurrent 401s don't
    /// race and invalidate the refresh token.
    private static let refreshLock = NSLock()
    private static var isRefreshing = false

    struct SupabaseError: LocalizedError {

        let statusCode: Int
        let message: String

        var errorDescription: String? {
            "Supabase error \(statusCode): \(message)"
        }

        var serverMessage: String? {
            guard let data = message.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                  let text = object["message"] as? String
                    ?? object["msg"] as? String
                    ?? object["error_description"] as? String
                    ?? object["error"] as? String else {
                return nil
            }
            return text
        }
    }

    // Replace with your project details from Supabase Dashboard -> Settings -> API
    private let baseURL = "https://xdyewakhzjnmpzhzhehl.supabase.co"
    private let apiKey = SupabaseConfig.anonKey

    private init() {}

    // MARK: - Headers & Requests

    private func makeRequest(
        endpoint: String,
        method: String = "GET"
    ) -> URLRequest {

        let url = URL(
            string: "\(baseURL)/rest/v1/\(endpoint)"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            apiKey,
            forHTTPHeaderField: "apikey"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        if let token = AuthTokenStore.shared.accessToken {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        } else {
            request.setValue(
                "Bearer \(apiKey)",
                forHTTPHeaderField: "Authorization"
            )
        }

        if method == "POST" || method == "PATCH" {
            request.setValue(
                "return=representation",
                forHTTPHeaderField: "Prefer"
            )
        }

        return request
    }

    private func perform(
        _ request: URLRequest
    ) async throws -> Data {

        let (data, response) = try await
            URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {

            let message = String(
                data: data,
                encoding: .utf8
            ) ?? "No response body"

            throw SupabaseError(
                statusCode: http.statusCode,
                message: message
            )
        }

        return data
    }

    /// Performs the request; on an expired-session 401 it refreshes
    /// the tokens once and retries transparently.
    private func performAuthorized(
        _ request: URLRequest
    ) async throws -> Data {

        do {
            return try await perform(request)
        } catch let error as SupabaseError {
            guard error.statusCode == 401,
                  AuthTokenStore.shared.hasToken else {
                throw error
            }
            Self.isRefreshing = true
            defer { Self.isRefreshing = false }

            guard (try? await SupabaseAuthService().refreshSession()) != nil,
                  let baseRequest = retriedRequest(request) else {
                throw error
            }

            var retried = baseRequest
            retried.setValue(
                "Bearer \(AuthTokenStore.shared.accessToken ?? "")",
                forHTTPHeaderField: "Authorization"
            )
            return try await perform(retried)

            Self.isRefreshing = true
            defer { Self.isRefreshing = false }

            guard let _ = try? await
                SupabaseAuthService().refreshSession(),
                  var retried = retriedRequest(request) else {
                throw error
            }

            retried.setValue(
                "Bearer \(AuthTokenStore.shared.accessToken ?? "")",
                forHTTPHeaderField: "Authorization"
            )
            return try await perform(retried)
        }
    }

    private func retriedRequest(
        _ request: URLRequest
    ) -> URLRequest? {
        var copy = request
        copy.httpBody = request.httpBody
        return copy
    }

    // MARK: - Date Handling

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()

        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        let formatterStandard = ISO8601DateFormatter()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date =
                formatterWithFractional.date(from: dateString)
                ?? formatterStandard.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Invalid ISO8601 date string: \(dateString)"
            )
        }

        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }

        return encoder
    }

    // MARK: - Bars

    /// Fetch all bars mapped to domain Bar models
    func fetchBars() async throws -> [Bar] {

        let request = makeRequest(endpoint: "bars?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [BarDTO].self,
            from: data
        )

        return dtos.map { $0.toDomain }
    }

    /// Add a new bar using Bar domain model
    func addBar(_ bar: Bar) async throws {

        var request = makeRequest(
            endpoint: "bars",
            method: "POST"
        )

        let dto = BarDTO(from: bar)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    /// Delete a bar and its prices (prices cascade)
    func deleteBar(_ bar: Bar) async throws {

        let request = makeRequest(
            endpoint: "bars?id=eq.\(bar.id.uuidString)",
            method: "DELETE"
        )

        _ = try await performAuthorized(request)
    }

    /// Update an existing bar
    func updateBar(_ bar: Bar) async throws {

        var request = makeRequest(
            endpoint: "bars?id=eq.\(bar.id.uuidString)",
            method: "PATCH"
        )

        let dto = BarDTO(from: bar)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    // MARK: - Prices

    /// Fetch every price entry, mapped to domain Price models
    func fetchAllPrices() async throws -> [Price] {

        let request = makeRequest(endpoint: "prices?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [PriceDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
    }

    /// Fetch prices for a specific bar mapped to domain Price models
    func fetchPrices(for barID: UUID) async throws -> [Price] {

        let request = makeRequest(
            endpoint:
                "prices?bar_id=eq.\(barID.uuidString)&select=*"
        )

        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [PriceDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
    }

    /// Add a new price entry using Price domain model
    func addPrice(_ price: Price) async throws {

        var request = makeRequest(
            endpoint: "prices",
            method: "POST"
        )

        let dto = PriceDTO(from: price)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    /// Update an existing price entry
    func updatePrice(_ price: Price) async throws {

        var request = makeRequest(
            endpoint: "prices?id=eq.\(price.id.uuidString)",
            method: "PATCH"
        )

        let dto = PriceDTO(from: price)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    /// Delete a price entry
    func deletePrice(_ price: Price) async throws {

        let request = makeRequest(
            endpoint: "prices?id=eq.\(price.id.uuidString)",
            method: "DELETE"
        )

        _ = try await performAuthorized(request)
    }

    // MARK: - Bar Ratings

    /// Fetch every ambience/wine rating, mapped to domain BarRating models
    func fetchBarRatings() async throws -> [BarRating] {

        let request = makeRequest(endpoint: "bar_ratings?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [BarRatingDTO].self,
            from: data
        )

        return dtos.map { $0.toDomain }
    }

    /// Insert or update a user's rating for a bar (one row per
    /// bar/user pair, matched on the `bar_ratings_bar_id_rated_by_key`
    /// unique constraint).
    func upsertBarRating(_ rating: BarRating) async throws {

        var request = makeRequest(
            endpoint: "bar_ratings?on_conflict=bar_id,rated_by",
            method: "POST"
        )

        request.setValue(
            "resolution=merge-duplicates,return=representation",
            forHTTPHeaderField: "Prefer"
        )

        let dto = BarRatingDTO(from: rating)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    // MARK: - Drink Ratings

    /// Fetch drink ratings for a specific bar.
    func fetchDrinkRatings(for barID: UUID) async throws -> [DrinkRating] {

        let request = makeRequest(
            endpoint: "drink_ratings?bar_id=eq.\(barID.uuidString)&select=*"
        )

        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [DrinkRatingDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
    }

    /// Fetch all drink ratings.
    func fetchAllDrinkRatings() async throws -> [DrinkRating] {

        let request = makeRequest(endpoint: "drink_ratings?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [DrinkRatingDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
    }

    /// Insert or update a user's drink rating (upsert on
    /// bar_id + drink + brand + size + rated_by).
    func upsertDrinkRating(_ rating: DrinkRating) async throws {

        var request = makeRequest(
            endpoint: "drink_ratings?on_conflict=bar_id,drink,brand,size,rated_by",
            method: "POST"
        )

        request.setValue(
            "resolution=merge-duplicates,return=representation",
            forHTTPHeaderField: "Prefer"
        )

        let dto = DrinkRatingDTO(from: rating)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    // MARK: - Drink Brands

    /// Fetch the shared, admin-approved brand catalog.
    func fetchBrands() async throws -> [DrinkBrand] {

        let request = makeRequest(endpoint: "drink_brands?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [DrinkBrandDTO].self,
            from: data
        )

        return dtos.map { $0.toDomain }
    }

    /// Add a brand to the shared catalog (used when an admin
    /// approves a request).
    func insertBrand(drink: Drink, name: String) async throws {

        var request = makeRequest(
            endpoint: "drink_brands",
            method: "POST"
        )

        struct NewBrand: Codable {
            let drink: String
            let name: String
        }

        request.httpBody = try encoder.encode(
            NewBrand(drink: drink.rawValue, name: name)
        )

        _ = try await performAuthorized(request)
    }

    // MARK: - Brand Requests

    func fetchBrandRequests() async throws -> [BrandRequest] {

        let request = makeRequest(endpoint: "brand_requests?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [BrandRequestDTO].self,
            from: data
        )

        return dtos.map { $0.toDomain }
    }

    func submitBrandRequest(_ request: BrandRequest) async throws {

        var httpRequest = makeRequest(
            endpoint: "brand_requests",
            method: "POST"
        )

        let dto = BrandRequestDTO(from: request)
        httpRequest.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(httpRequest)
    }

    func updateBrandRequestStatus(
        _ requestID: UUID,
        status: BrandRequestStatus
    ) async throws {

        var httpRequest = makeRequest(
            endpoint: "brand_requests?id=eq.\(requestID.uuidString)",
            method: "PATCH"
        )

        struct StatusUpdate: Codable {
            let status: String
        }

        httpRequest.httpBody = try encoder.encode(
            StatusUpdate(status: status.rawValue)
        )

        _ = try await performAuthorized(httpRequest)
    }

    func deleteBrandRequest(_ request: BrandRequest) async throws {
        let httpRequest = makeRequest(
            endpoint: "brand_requests?id=eq.\(request.id.uuidString)",
            method: "DELETE"
        )
        _ = try await performAuthorized(httpRequest)
    }

    // MARK: - Content Reports

    func fetchContentReports() async throws -> [ContentReport] {

        let request = makeRequest(endpoint: "content_reports?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [ContentReportDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
        
    }

    func insertContentReport(_ report: ContentReport) async throws {

        var request = makeRequest(
            endpoint: "content_reports",
            method: "POST"
        )

        let dto = ContentReportDTO(from: report)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    func markContentReportReviewed(
        _ reportID: UUID,
        reviewedAt: Date
    ) async throws {

        var request = makeRequest(
            endpoint: "content_reports?id=eq.\(reportID.uuidString)",
            method: "PATCH"
        )

        struct ReviewUpdate: Codable {
            let is_reviewed: Bool
            let reviewed_at: Date
        }

        request.httpBody = try encoder.encode(
            ReviewUpdate(is_reviewed: true, reviewed_at: reviewedAt)
        )

        _ = try await performAuthorized(request)
    }

    func deleteContentReport(_ reportID: UUID) async throws {

        let request = makeRequest(
            endpoint: "content_reports?id=eq.\(reportID.uuidString)",
            method: "DELETE"
        )

        _ = try await performAuthorized(request)
    }

    // MARK: - Profile

    func fetchProfile(
        userID: UUID
    ) async throws -> ProfileDTO {

        let request = makeRequest(
            endpoint: "profiles?select=*&id=eq.\(userID.uuidString)"
        )

        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [ProfileDTO].self,
            from: data
        )

        guard let profile = dtos.first else {
            throw SupabaseError(
                statusCode: 404,
                message: "Profile not found"
            )
        }

        return profile
    }

    func updateProfileDisplayName(
        userID: UUID,
        displayName: String
    ) async throws {
        var httpRequest = makeRequest(
            endpoint: "profiles?id=eq.\(userID.uuidString)",
            method: "PATCH"
        )
        httpRequest.httpBody = try JSONEncoder().encode(
            ["display_name": displayName]
        )
        _ = try await performAuthorized(httpRequest)
    }

    func updateProfileAvatarURL(
        userID: UUID,
        avatarURL: String
    ) async throws {
        var httpRequest = makeRequest(
            endpoint: "profiles?id=eq.\(userID.uuidString)",
            method: "PATCH"
        )
        httpRequest.httpBody = try JSONEncoder().encode(
            ["avatar_url": avatarURL]
        )
        _ = try await performAuthorized(httpRequest)
    }

    // MARK: - Storage (avatars)

    /// Uploads JPEG data to the public `avatars` bucket under the
    /// user's own folder and returns the public URL.
    func uploadAvatar(
        userID: UUID,
        jpegData: Data
    ) async throws -> URL {

        let path = "avatars/\(userID.uuidString)/avatar.jpg"
        let url = URL(
            string: "\(baseURL)/storage/v1/object/\(path)"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        if let token = AuthTokenStore.shared.accessToken {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        request.setValue(
            "image/jpeg",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            "true",
            forHTTPHeaderField: "x-upsert"
        )
        request.httpBody = jpegData

        _ = try await performAuthorized(request)

        return URL(
            string: "\(baseURL)/storage/v1/object/public/\(path)"
        )!
    }
}
