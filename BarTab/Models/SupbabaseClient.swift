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

/// Builds shareable deep links that open BarTab to a specific screen.
enum DeepLink {

    static let scheme = SupabaseConfig.oauthCallbackScheme

    /// Universal Link host. Only used once the app has the paid Developer
    /// Program (the Associated Domains entitlement is unavailable on free
    /// personal teams). Until then, share links use `bartab://…`.
    static let host = "bartap.info"

    static func bar(_ id: UUID) -> URL {
        URL(string: "\(scheme)://bar/\(id.uuidString)")!
    }

    static func group(_ id: UUID) -> URL {
        URL(string: "\(scheme)://group/\(id.uuidString)")!
    }
}

/// Holds the signed-in user's access token so every REST call runs
/// with the caller's identity (required once Row Level Security is
/// enabled   the anon key alone fails every `auth.uid()` check).
final class AuthTokenStore {

    static let shared = AuthTokenStore()

    private let lock = NSLock()

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var expiresAt: Date?
    private(set) var userID: UUID?

    private init() {}

    var hasToken: Bool {
        lock.lock()
        defer { lock.unlock() }
        return accessToken != nil
    }

    func update(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date?,
        userID: UUID? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        if let userID { self.userID = userID }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        userID = nil
    }
}

/// Thin Supabase REST (PostgREST + Auth + Storage) client.
///
/// The URL and anon key come from Supabase Dashboard -> Settings -> API.
/// The anon key is safe to ship in the app by design   it only unlocks
/// whatever your Row Level Security policies allow.
final class SupabaseClient {

    static let shared = SupabaseClient()

    /// Serializes token-refresh attempts so concurrent 401s don't
    /// race and invalidate the refresh token.
    private static let refreshLock = NSLock()
    private static var isRefreshing = false

    /// Decoded user ID from the current JWT. Nil when not signed in.
    var currentUserID: UUID? {
        if let id = AuthTokenStore.shared.userID { return id }
        guard let token = AuthTokenStore.shared.accessToken else { return nil }
        // JWT format: header.payload.signature
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Data(base64Encoded: String(parts[1])
                  .replacingOccurrences(of: "-", with: "+")
                  .replacingOccurrences(of: "_", with: "/")),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let sub = json["sub"] as? String
        else { return nil }
        return UUID(uuidString: sub)
    }

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
    ) throws -> URLRequest {

        let urlString = "\(baseURL)/rest/v1/\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError(
                statusCode: 0,
                message: "Invalid URL: \(urlString)"
            )
        }

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

            Self.refreshLock.lock()
            guard !Self.isRefreshing else {
                Self.refreshLock.unlock()
                throw error
            }
            Self.isRefreshing = true
            Self.refreshLock.unlock()

            defer {
                Self.refreshLock.lock()
                Self.isRefreshing = false
                Self.refreshLock.unlock()
            }

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

        let request = try makeRequest(endpoint: "bars?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [BarDTO].self,
            from: data
        )

        let bars = dtos.map { $0.toDomain }
        return bars
    }

    /// Add a new bar using Bar domain model
    func addBar(_ bar: Bar) async throws {

        var request = try makeRequest(
            endpoint: "bars",
            method: "POST"
        )

        let dto = BarDTO(from: bar)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    /// Delete a bar and its prices (prices cascade)
    func deleteBar(_ bar: Bar) async throws {

        let request = try makeRequest(
            endpoint: "bars?id=eq.\(bar.id.uuidString)",
            method: "DELETE"
        )

        _ = try await performAuthorized(request)
    }

    /// Update an existing bar
    func updateBar(_ bar: Bar) async throws {

        var request = try makeRequest(
            endpoint: "bars?id=eq.\(bar.id.uuidString)",
            method: "PATCH"
        )
        request.setValue(
            "return=representation",
            forHTTPHeaderField: "Prefer"
        )

        let dto = BarPatchDTO(from: bar)
        request.httpBody = try encoder.encode(dto)

        let data = try await performAuthorized(request)

        // PostgREST returns 200 even when RLS blocks the update
        // (0 rows affected). Decode the response to verify the
        // update actually landed.
        let updated = try decoder.decode([BarDTO].self, from: data)
        guard !updated.isEmpty else {
            throw SupabaseError(
                statusCode: 403,
                message: "Update blocked   you may not have permission to change this bar."
            )
        }
    }

    // MARK: - Prices

    /// Fetch every price entry, mapped to domain Price models
    func fetchAllPrices() async throws -> [Price] {

        let request = try makeRequest(endpoint: "prices?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [PriceDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
    }

    /// Fetch prices for a specific bar mapped to domain Price models
    func fetchPrices(for barID: UUID) async throws -> [Price] {

        let request = try makeRequest(
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

        var request = try makeRequest(
            endpoint: "prices",
            method: "POST"
        )

        let dto = PriceDTO(from: price)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    /// Update an existing price entry
    func updatePrice(_ price: Price) async throws {

        var request = try makeRequest(
            endpoint: "prices?id=eq.\(price.id.uuidString)",
            method: "PATCH"
        )

        let dto = PriceDTO(from: price)
        request.httpBody = try encoder.encode(dto)

        _ = try await performAuthorized(request)
    }

    /// Delete a price entry
    func deletePrice(_ price: Price) async throws {

        let request = try makeRequest(
            endpoint: "prices?id=eq.\(price.id.uuidString)",
            method: "DELETE"
        )

        _ = try await performAuthorized(request)
    }

    // MARK: - Price Verification

    /// Fetch every "still accurate" confirmation.
    func fetchPriceVerifications() async throws -> [PriceVerification] {
        let request = try makeRequest(endpoint: "price_verifications?select=*")
        let data = try await performAuthorized(request)
        return try decoder.decode([PriceVerification].self, from: data)
    }

    /// Record (or re-record) the current user's verification for a price.
    /// Upserts on `price_id + user_id` and bumps `created_at`, so the
    /// freshness date refreshes on each tap.
    func verifyPrice(priceID: UUID) async throws {
        struct VerifyBody: Codable {
            let price_id: UUID
            let user_id: UUID
            let created_at: Date
        }

        let body = VerifyBody(
            price_id: priceID,
            user_id: try requireUserID(),
            created_at: Date()
        )

        var request = try makeRequest(
            endpoint: "price_verifications?on_conflict=price_id,user_id",
            method: "POST"
        )
        request.setValue(
            "resolution=merge-duplicates,return=representation",
            forHTTPHeaderField: "Prefer"
        )
        request.httpBody = try encoder.encode(body)
        _ = try await performAuthorized(request)
    }

    /// Remove the current user's verification for a price.
    func unverifyPrice(priceID: UUID) async throws {
        let myID = try requireUserID().uuidString
        var request = try makeRequest(
            endpoint: "price_verifications?price_id=eq.\(priceID.uuidString)&user_id=eq.\(myID)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    // MARK: - Bar Ratings

    /// Fetch every ambience/wine rating, mapped to domain BarRating models
    func fetchBarRatings() async throws -> [BarRating] {

        let request = try makeRequest(endpoint: "bar_ratings?select=*")
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

        var request = try makeRequest(
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

        let request = try makeRequest(
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

        let request = try makeRequest(endpoint: "drink_ratings?select=*")
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

        var request = try makeRequest(
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

        let request = try makeRequest(endpoint: "drink_brands?select=*")
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

        var request = try makeRequest(
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

        let request = try makeRequest(endpoint: "brand_requests?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [BrandRequestDTO].self,
            from: data
        )

        return dtos.map { $0.toDomain }
    }

    func submitBrandRequest(_ request: BrandRequest) async throws {

        var httpRequest = try makeRequest(
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

        var httpRequest = try makeRequest(
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
        let httpRequest = try makeRequest(
            endpoint: "brand_requests?id=eq.\(request.id.uuidString)",
            method: "DELETE"
        )
        _ = try await performAuthorized(httpRequest)
    }

    // MARK: - Content Reports

    func fetchContentReports() async throws -> [ContentReport] {

        let request = try makeRequest(endpoint: "content_reports?select=*")
        let data = try await performAuthorized(request)

        let dtos = try decoder.decode(
            [ContentReportDTO].self,
            from: data
        )

        return dtos.compactMap { $0.toDomain }
        
    }

    func insertContentReport(_ report: ContentReport) async throws {

        var request = try makeRequest(
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

        var request = try makeRequest(
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

        let request = try makeRequest(
            endpoint: "content_reports?id=eq.\(reportID.uuidString)",
            method: "DELETE"
        )

        _ = try await performAuthorized(request)
    }

    // MARK: - Profile

    func fetchProfile(
        userID: UUID
    ) async throws -> ProfileDTO {

        let request = try makeRequest(
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
        var httpRequest = try makeRequest(
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
        var httpRequest = try makeRequest(
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
        guard let url = URL(
            string: "\(baseURL)/storage/v1/object/\(path)"
        ) else {
            throw SupabaseError(statusCode: 0, message: "Invalid avatar URL")
        }

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

        guard let publicURL = URL(
            string: "\(baseURL)/storage/v1/object/public/\(path)"
        ) else {
            throw SupabaseError(statusCode: 0, message: "Invalid avatar public URL")
        }
        return publicURL
    }

    /// Throws if no user is signed in.
    private func requireUserID() throws -> UUID {
        guard let id = currentUserID else {
            throw SupabaseError(statusCode: 401, message: "Not signed in")
        }
        return id
    }

    // MARK: - Follow Requests

    func sendFollowRequest(_ userID: UUID) async throws {
        let body: [String: Any] = [
            "follower_id": try requireUserID().uuidString,
            "following_id": userID.uuidString,
            "status": "pending"
        ]
        var request = try makeRequest(endpoint: "follows", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func cancelFollowRequest(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        var request = try makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&following_id=eq.\(theirID)&status=eq.pending",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    func approveFollowRequest(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        let body: [String: Any] = ["status": "accepted"]
        var request = try makeRequest(
            endpoint: "follows?follower_id=eq.\(theirID)&following_id=eq.\(myID)&status=eq.pending",
            method: "PATCH"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func rejectFollowRequest(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        let body: [String: Any] = ["status": "rejected"]
        var request = try makeRequest(
            endpoint: "follows?follower_id=eq.\(theirID)&following_id=eq.\(myID)&status=eq.pending",
            method: "PATCH"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func removeFollow(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        var request = try makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&following_id=eq.\(theirID)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    enum FollowStatus {
        case none
        case pendingOutgoing
        case pendingIncoming
        case accepted
    }

    func fetchFollowStatus(for userID: UUID) async throws -> FollowStatus {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString

        // Check outgoing: I → them
        let outReq = try makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&following_id=eq.\(theirID)&select=status"
        )
        let outData = try await performAuthorized(outReq)
        let outRows = try decoder.decode([Follow].self, from: outData)
        if let first = outRows.first {
            return first.status == "accepted" ? .accepted : .pendingOutgoing
        }

        // Check incoming: them → I
        let inReq = try makeRequest(
            endpoint: "follows?follower_id=eq.\(theirID)&following_id=eq.\(myID)&select=status"
        )
        let inData = try await performAuthorized(inReq)
        let inRows = try decoder.decode([Follow].self, from: inData)
        if let first = inRows.first {
            return first.status == "accepted" ? .accepted : .pendingIncoming
        }

        return .none
    }

    func fetchIncomingFollowRequests() async throws -> [Follow] {
        let myID = try requireUserID().uuidString
        let request = try makeRequest(
            endpoint: "follows?following_id=eq.\(myID)&status=eq.pending&select=*,follower_id"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([Follow].self, from: data)
    }

    func fetchProfilesByIDs(_ ids: [UUID]) async throws -> [UUID: ProfileDTO] {
        guard !ids.isEmpty else { return [:] }
        let idList = ids.map(\.uuidString).joined(separator: ",")
        let request = try makeRequest(
            endpoint: "profiles?id=in.(\(idList))&select=*"
        )
        let data = try await performAuthorized(request)
        let profiles = try decoder.decode([ProfileDTO].self, from: data)
        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    func fetchFollowing() async throws -> [UUID] {
        let myID = try requireUserID().uuidString
        let request = try makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&status=eq.accepted&select=following_id"
        )
        let data = try await performAuthorized(request)
        let rows = try decoder.decode([Follow].self, from: data)
        return rows.map(\.followingID)
    }

    func fetchFollowerCount(for userID: UUID) async throws -> Int {
        let request = try makeRequest(
            endpoint: "follows?following_id=eq.\(userID.uuidString)&status=eq.accepted&select=follower_id"
        )
        let data = try await performAuthorized(request)
        let rows = try decoder.decode([Follow].self, from: data)
        return rows.count
    }

    func fetchFollowingCount(for userID: UUID) async throws -> Int {
        let request = try makeRequest(
            endpoint: "follows?follower_id=eq.\(userID.uuidString)&status=eq.accepted&select=following_id"
        )
        let data = try await performAuthorized(request)
        let rows = try decoder.decode([Follow].self, from: data)
        return rows.count
    }

    func searchUsers(query: String) async throws -> [ProfileDTO] {
        let myID = try requireUserID().uuidString
        let wildcard = "%25\(query)%25"
        let endpoint = "profiles?id=neq.\(myID)&display_name=ilike.\(wildcard)&select=*&limit=20"
        let request = try makeRequest(endpoint: endpoint)
        let data = try await performAuthorized(request)
        return try decoder.decode([ProfileDTO].self, from: data)
    }

    // MARK: - Activity Feed

    func fetchActivityFeed(followingIDs: [UUID]) async throws -> [ActivityItem] {
        guard !followingIDs.isEmpty else { return [] }

        let ids = followingIDs.map(\.uuidString).joined(separator: ",")
        var items: [ActivityItem] = []

        // Recent prices from followed users
        let priceReq = try makeRequest(
            endpoint: "prices?reported_by=in.(\(ids))&select=*,bars(name)&order=reported_at.desc&limit=30"
        )
        let priceData = try await performAuthorized(priceReq)
        let priceRows = try decoder.decode([PriceDTO].self, from: priceData)
        for row in priceRows {
            items.append(ActivityItem(
                id: row.id,
                userID: row.reported_by,
                kind: .priceReport(
                    barName: row.bars?.name ?? "Unknown",
                    drink: row.drink,
                    amount: row.amount,
                    currency: row.currency
                ),
                timestamp: row.reported_at,
                barID: row.bar_id
            ))
        }

        // Recent bar ratings from followed users
        let ratingReq = try makeRequest(
            endpoint: "bar_ratings?rated_by=in.(\(ids))&select=*,bars(name)&order=created_at.desc&limit=20"
        )
        let ratingData = try await performAuthorized(ratingReq)
        let ratingRows = try decoder.decode([BarRatingDTO].self, from: ratingData)
        for row in ratingRows {
            items.append(ActivityItem(
                id: row.id,
                userID: row.rated_by,
                kind: .barRating(
                    barName: row.bars?.name ?? "Unknown",
                    ambience: row.ambience
                ),
                timestamp: row.created_at,
                barID: row.bar_id
            ))
        }

        // Recent drink ratings from followed users
        let drinkRatingReq = try makeRequest(
            endpoint: "drink_ratings?rated_by=in.(\(ids))&select=*,bars(name)&order=created_at.desc&limit=20"
        )
        let drinkRatingData = try await performAuthorized(drinkRatingReq)
        let drinkRatingRows = try decoder.decode([DrinkRatingDTO].self, from: drinkRatingData)
        for row in drinkRatingRows {
            items.append(ActivityItem(
                id: row.id,
                userID: row.rated_by,
                kind: .drinkRating(
                    barName: row.bars?.name ?? "Unknown",
                    drink: row.drink,
                    quality: row.quality
                ),
                timestamp: row.created_at,
                barID: row.bar_id
            ))
        }

        // Bars created by followed users
        let barReq = try makeRequest(
            endpoint: "bars?created_by=in.(\(ids))&select=*&order=created_at.desc&limit=10"
        )
        let barData = try await performAuthorized(barReq)
        let barRows = try decoder.decode([BarDTO].self, from: barData)
        for row in barRows {
            let bar = row.toDomain
            items.append(ActivityItem(
                id: UUID(),
                userID: row.created_by,
                kind: .barCreated(barName: bar.name),
                timestamp: row.created_at,
                barID: bar.id
            ))
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Groups

    func createGroup(name: String) async throws -> BarGroup {
        let userID = try requireUserID()
        let body: [String: Any] = [
            "name": name,
            "created_by": userID.uuidString
        ]
        var request = try makeRequest(endpoint: "groups", method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performAuthorized(request)
        let rows = try decoder.decode([BarGroup].self, from: data)
        guard let group = rows.first else {
            throw SupabaseError(statusCode: 200, message: "Failed to create group")
        }

        // Add creator as admin member
        let memberBody: [String: Any] = [
            "group_id": group.id.uuidString,
            "user_id": userID.uuidString,
            "role": "admin"
        ]
        var memberReq = try makeRequest(endpoint: "group_members", method: "POST")
        memberReq.httpBody = try JSONSerialization.data(withJSONObject: memberBody)
        _ = try await performAuthorized(memberReq)

        return group
    }

    func fetchGroups() async throws -> [BarGroup] {
        let myID = try requireUserID().uuidString

        // Fetch groups where user is a member
        let memberRequest = try makeRequest(
            endpoint: "group_members?user_id=eq.\(myID)&select=group_id"
        )
        let memberData = try await performAuthorized(memberRequest)
        let memberRows = try decoder.decode([GroupMemberID].self, from: memberData)
        var groupIDs = Set(memberRows.map { $0.groupID.uuidString })

        // Also fetch groups the user created (fallback for RLS edge cases)
        let createdRequest = try makeRequest(
            endpoint: "groups?created_by=eq.\(myID)&select=id"
        )
        let createdData = try await performAuthorized(createdRequest)
        let createdRows = try decoder.decode([GroupIDOnly].self, from: createdData)
        for row in createdRows {
            groupIDs.insert(row.id.uuidString)
        }

        guard !groupIDs.isEmpty else { return [] }
        let idList = groupIDs.joined(separator: ",")
        let groupsRequest = try makeRequest(
            endpoint: "groups?id=in.(\(idList))&select=*"
        )
        let groupsData = try await performAuthorized(groupsRequest)
        return try decoder.decode([BarGroup].self, from: groupsData)
    }

    func fetchGroup(id: UUID) async throws -> BarGroup? {
        let request = try makeRequest(
            endpoint: "groups?id=eq.\(id.uuidString)&select=*"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([BarGroup].self, from: data).first
    }

    func fetchGroupMembers(groupID: UUID) async throws -> [GroupMember] {
        let request = try makeRequest(
            endpoint: "group_members?group_id=eq.\(groupID.uuidString)&select=*"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([GroupMember].self, from: data)
    }

    func inviteToGroup(groupID: UUID, userID: UUID) async throws {
        let body: [String: Any] = [
            "group_id": groupID.uuidString,
            "user_id": userID.uuidString,
            "role": "member"
        ]
        var request = try makeRequest(endpoint: "group_members", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func leaveGroup(groupID: UUID) async throws {
        let myID = try requireUserID().uuidString
        var request = try makeRequest(
            endpoint: "group_members?group_id=eq.\(groupID.uuidString)&user_id=eq.\(myID)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    // MARK: - Polls

    func createPoll(groupID: UUID, title: String, options: [(barID: UUID?, label: String)]) async throws -> Poll {
        let pollBody: [String: Any] = [
            "group_id": groupID.uuidString,
            "title": title,
            "created_by": try requireUserID().uuidString
        ]
        var pollReq = try makeRequest(endpoint: "group_polls", method: "POST")
        pollReq.setValue("return=representation", forHTTPHeaderField: "Prefer")
        pollReq.httpBody = try JSONSerialization.data(withJSONObject: pollBody)

        let pollData = try await performAuthorized(pollReq)
        let pollRows = try decoder.decode([Poll].self, from: pollData)
        guard let poll = pollRows.first else {
            throw SupabaseError(statusCode: 200, message: "Failed to create poll")
        }

        for option in options {
            var optBody: [String: Any] = [
                "poll_id": poll.id.uuidString,
                "label": option.label,
                "created_by": try requireUserID().uuidString
            ]
            if let barID = option.barID {
                optBody["bar_id"] = barID.uuidString
            }
            var optReq = try makeRequest(endpoint: "poll_options", method: "POST")
            optReq.httpBody = try JSONSerialization.data(withJSONObject: optBody)
            _ = try await performAuthorized(optReq)
        }

        return poll
    }

    func fetchPolls(groupID: UUID) async throws -> [Poll] {
        let request = try makeRequest(
            endpoint: "group_polls?group_id=eq.\(groupID.uuidString)&select=*&order=created_at.desc"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([Poll].self, from: data)
    }

    func fetchPollOptions(pollID: UUID) async throws -> [PollOption] {
        let request = try makeRequest(
            endpoint: "poll_options?poll_id=eq.\(pollID.uuidString)&select=*"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([PollOption].self, from: data)
    }

    func fetchPollVotes(pollID: UUID) async throws -> [PollVote] {
        let request = try makeRequest(
            endpoint: "poll_votes?poll_id=eq.\(pollID.uuidString)&select=*"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([PollVote].self, from: data)
    }

    func votePoll(pollID: UUID, optionID: UUID) async throws {
        let myID = try requireUserID().uuidString

        // Remove existing vote for this poll
        var deleteReq = try makeRequest(
            endpoint: "poll_votes?poll_id=eq.\(pollID.uuidString)&user_id=eq.\(myID)",
            method: "DELETE"
        )
        _ = try await performAuthorized(deleteReq)

        // Insert new vote
        let body: [String: Any] = [
            "poll_id": pollID.uuidString,
            "option_id": optionID.uuidString,
            "user_id": myID
        ]
        var voteReq = try makeRequest(endpoint: "poll_votes", method: "POST")
        voteReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(voteReq)
    }

    func closePoll(pollID: UUID) async throws {
        let body: [String: Any] = ["is_closed": true]
        var request = try makeRequest(
            endpoint: "group_polls?id=eq.\(pollID.uuidString)",
            method: "PATCH"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func deleteGroup(groupID: UUID) async throws {
        let myID = try requireUserID().uuidString
        // Verify the user is admin of this group
        let memberReq = try makeRequest(
            endpoint: "group_members?group_id=eq.\(groupID.uuidString)&user_id=eq.\(myID)&role=eq.admin&select=*"
        )
        let memberData = try await performAuthorized(memberReq)
        let members = try decoder.decode([GroupMember].self, from: memberData)
        guard !members.isEmpty else {
            throw SupabaseError(statusCode: 403, message: "Only group admins can delete a group")
        }
        var request = try makeRequest(
            endpoint: "groups?id=eq.\(groupID.uuidString)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    func removeMember(groupID: UUID, userID: UUID) async throws {
        var request = try makeRequest(
            endpoint: "group_members?group_id=eq.\(groupID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    func fetchProfileNamesByIDs(_ ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let idList = ids.map(\.uuidString).joined(separator: ",")
        let request = try makeRequest(
            endpoint: "profiles?id=in.(\(idList))&select=id,display_name"
        )
        let data = try await performAuthorized(request)
        let names = try decoder.decode([ProfileNameRow].self, from: data)
        var result: [UUID: String] = [:]
        for row in names {
            result[row.id] = row.displayName ?? "User"
        }
        return result
    }

    // MARK: - Price Alerts

    func createPriceAlert(
        barID: UUID,
        drink: String,
        size: String,
        brand: String?,
        targetPrice: Double?
    ) async throws -> PriceAlert {
        var body: [String: Any] = [
            "user_id": try requireUserID().uuidString,
            "bar_id": barID.uuidString,
            "drink": drink,
            "size": size
        ]
        if let brand {
            body["brand"] = brand
        }
        if let targetPrice {
            body["target_price"] = targetPrice
        }
        var request = try makeRequest(endpoint: "price_alerts", method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performAuthorized(request)
        let rows = try decoder.decode([PriceAlert].self, from: data)
        guard let alert = rows.first else {
            throw SupabaseError(statusCode: 200, message: "Failed to create alert")
        }
        return alert
    }

    func fetchPriceAlerts() async throws -> [PriceAlert] {
        let myID = try requireUserID().uuidString
        let request = try makeRequest(
            endpoint: "price_alerts?user_id=eq.\(myID)&is_active=eq.true&select=*&order=created_at.desc"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([PriceAlert].self, from: data)
    }

    func deletePriceAlert(_ alertID: UUID) async throws {
        var request = try makeRequest(
            endpoint: "price_alerts?id=eq.\(alertID.uuidString)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    // MARK: - Account deletion

    /// Calls the `delete-account` Edge Function, which deletes the caller's
    /// auth user (and cascades their data) using the service role key.
    func deleteAccount() async throws {
        guard let url = URL(
            string: "\(baseURL)/functions/v1/delete-account"
        ) else {
            throw SupabaseError(statusCode: 0, message: "Invalid delete-account URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        if let token = AuthTokenStore.shared.accessToken {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        _ = try await performAuthorized(request)
    }
}
