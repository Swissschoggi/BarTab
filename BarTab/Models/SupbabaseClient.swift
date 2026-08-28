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
/// The anon key is safe to ship in the app by design — it only unlocks
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
    ) -> URLRequest {

        let urlString = "\(baseURL)/rest/v1/\(endpoint)"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL: \(urlString)")
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

        let bars = dtos.map { $0.toDomain }
        print("[SupabaseClient] fetchBars: \(bars.count) bars, outdoor=\(bars.filter(\.outdoorSeating).count), smoking=\(bars.filter(\.smokingFriendly).count)")
        return bars
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
                message: "Update blocked — you may not have permission to change this bar."
            )
        }
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
        request.httpMethod = "PUT"
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
        var request = makeRequest(endpoint: "follows", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func cancelFollowRequest(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        var request = makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&following_id=eq.\(theirID)&status=eq.pending",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }

    func approveFollowRequest(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        let body: [String: Any] = ["status": "accepted"]
        var request = makeRequest(
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
        var request = makeRequest(
            endpoint: "follows?follower_id=eq.\(theirID)&following_id=eq.\(myID)&status=eq.pending",
            method: "PATCH"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func removeFollow(_ userID: UUID) async throws {
        let myID = try requireUserID().uuidString
        let theirID = userID.uuidString
        var request = makeRequest(
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
        let outReq = makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&following_id=eq.\(theirID)&select=status"
        )
        let outData = try await performAuthorized(outReq)
        let outRows = try decoder.decode([Follow].self, from: outData)
        if let first = outRows.first {
            return first.status == "accepted" ? .accepted : .pendingOutgoing
        }

        // Check incoming: them → I
        let inReq = makeRequest(
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
        let request = makeRequest(
            endpoint: "follows?following_id=eq.\(myID)&status=eq.pending&select=*,follower_id"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([Follow].self, from: data)
    }

    func fetchProfilesByIDs(_ ids: [UUID]) async throws -> [UUID: ProfileDTO] {
        guard !ids.isEmpty else { return [:] }
        let idList = ids.map(\.uuidString).joined(separator: ",")
        let request = makeRequest(
            endpoint: "profiles?id=in.(\(idList))&select=*"
        )
        let data = try await performAuthorized(request)
        let profiles = try decoder.decode([ProfileDTO].self, from: data)
        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    func fetchFollowing() async throws -> [UUID] {
        let myID = try requireUserID().uuidString
        let request = makeRequest(
            endpoint: "follows?follower_id=eq.\(myID)&status=eq.accepted&select=following_id"
        )
        let data = try await performAuthorized(request)
        let rows = try decoder.decode([Follow].self, from: data)
        return rows.map(\.followingID)
    }

    func fetchFollowerCount(for userID: UUID) async throws -> Int {
        let request = makeRequest(
            endpoint: "follows?following_id=eq.\(userID.uuidString)&status=eq.accepted&select=follower_id"
        )
        let data = try await performAuthorized(request)
        let rows = try decoder.decode([Follow].self, from: data)
        return rows.count
    }

    func fetchFollowingCount(for userID: UUID) async throws -> Int {
        let request = makeRequest(
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
        let request = makeRequest(endpoint: endpoint)
        let data = try await performAuthorized(request)
        return try decoder.decode([ProfileDTO].self, from: data)
    }

    // MARK: - Activity Feed

    func fetchActivityFeed(followingIDs: [UUID]) async throws -> [ActivityItem] {
        guard !followingIDs.isEmpty else { return [] }

        let ids = followingIDs.map(\.uuidString).joined(separator: ",")
        var items: [ActivityItem] = []

        // Recent prices from followed users
        let priceReq = makeRequest(
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
                timestamp: row.reported_at
            ))
        }

        // Recent bar ratings from followed users
        let ratingReq = makeRequest(
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
                timestamp: row.created_at
            ))
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Groups

    func createGroup(name: String) async throws -> BarGroup {
        let body: [String: Any] = [
            "name": name,
            "created_by": try requireUserID().uuidString
        ]
        var request = makeRequest(endpoint: "groups", method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performAuthorized(request)
        let rows = try decoder.decode([BarGroup].self, from: data)
        guard let group = rows.first else {
            throw SupabaseError(statusCode: 200, message: "Failed to create group")
        }

        // Auto-add creator as admin
        let memberBody: [String: Any] = [
            "group_id": group.id.uuidString,
            "user_id": try requireUserID().uuidString,
            "role": "admin"
        ]
        var memberReq = makeRequest(endpoint: "group_members", method: "POST")
        memberReq.httpBody = try JSONSerialization.data(withJSONObject: memberBody)
        _ = try await performAuthorized(memberReq)

        return group
    }

    func fetchGroups() async throws -> [BarGroup] {
        let myID = try requireUserID().uuidString
        let request = makeRequest(
            endpoint: "group_members?user_id=eq.\(myID)&select=group_id"
        )
        let data = try await performAuthorized(request)
        let memberRows = try decoder.decode([GroupMember].self, from: data)
        let groupIDs = memberRows.map { $0.groupID.uuidString }
        guard !groupIDs.isEmpty else { return [] }
        let idList = groupIDs.joined(separator: ",")
        let groupsRequest = makeRequest(
            endpoint: "groups?id=in.(\(idList))&select=*"
        )
        let groupsData = try await performAuthorized(groupsRequest)
        return try decoder.decode([BarGroup].self, from: groupsData)
    }

    func fetchGroupMembers(groupID: UUID) async throws -> [GroupMember] {
        let request = makeRequest(
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
        var request = makeRequest(endpoint: "group_members", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    func leaveGroup(groupID: UUID) async throws {
        let myID = try requireUserID().uuidString
        var request = makeRequest(
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
        var pollReq = makeRequest(endpoint: "group_polls", method: "POST")
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
            var optReq = makeRequest(endpoint: "poll_options", method: "POST")
            optReq.httpBody = try JSONSerialization.data(withJSONObject: optBody)
            _ = try await performAuthorized(optReq)
        }

        return poll
    }

    func fetchPolls(groupID: UUID) async throws -> [Poll] {
        let request = makeRequest(
            endpoint: "group_polls?group_id=eq.\(groupID.uuidString)&select=*&order=created_at.desc"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([Poll].self, from: data)
    }

    func fetchPollOptions(pollID: UUID) async throws -> [PollOption] {
        let request = makeRequest(
            endpoint: "poll_options?poll_id=eq.\(pollID.uuidString)&select=*"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([PollOption].self, from: data)
    }

    func fetchPollVotes(pollID: UUID) async throws -> [PollVote] {
        let request = makeRequest(
            endpoint: "poll_votes?poll_id=eq.\(pollID.uuidString)&select=*"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([PollVote].self, from: data)
    }

    func votePoll(pollID: UUID, optionID: UUID) async throws {
        let myID = try requireUserID().uuidString

        // Remove existing vote for this poll
        var deleteReq = makeRequest(
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
        var voteReq = makeRequest(endpoint: "poll_votes", method: "POST")
        voteReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(voteReq)
    }

    func closePoll(pollID: UUID) async throws {
        let body: [String: Any] = ["is_closed": true]
        var request = makeRequest(
            endpoint: "group_polls?id=eq.\(pollID.uuidString)",
            method: "PATCH"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await performAuthorized(request)
    }

    // MARK: - Price Alerts

    func createPriceAlert(
        barID: UUID,
        drink: String,
        size: String,
        brand: String?,
        targetPrice: Double?
    ) async throws -> PriceAlert {
        let body: [String: Any] = [
            "user_id": try requireUserID().uuidString,
            "bar_id": barID.uuidString,
            "drink": drink,
            "size": size,
            "brand": brand as Any,
            "target_price": targetPrice as Any
        ]
        var request = makeRequest(endpoint: "price_alerts", method: "POST")
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
        let request = makeRequest(
            endpoint: "price_alerts?user_id=eq.\(myID)&is_active=true&select=*&order=created_at.desc"
        )
        let data = try await performAuthorized(request)
        return try decoder.decode([PriceAlert].self, from: data)
    }

    func deletePriceAlert(_ alertID: UUID) async throws {
        var request = makeRequest(
            endpoint: "price_alerts?id=eq.\(alertID.uuidString)",
            method: "DELETE"
        )
        _ = try await performAuthorized(request)
    }
}
