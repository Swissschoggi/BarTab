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
}

/// Thin Supabase REST (PostgREST + Auth) client.
///
/// The URL and anon key come from Supabase Dashboard -> Settings -> API.
/// The anon key is safe to ship in the app by design — it only unlocks
/// whatever your Row Level Security policies allow.
final class SupabaseClient {

    static let shared = SupabaseClient()

    struct SupabaseError: LocalizedError {

        let statusCode: Int
        let message: String

        var errorDescription: String? {
            "Supabase error \(statusCode): \(message)"
        }
    }

    // Replace with your project details from Supabase Dashboard -> Settings -> API
    private let baseURL = "https://xdyewakhzjnmpzhzhehl.supabase.co"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhkeWV3YWtoempubXB6aHpoZWhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwODc2MjksImV4cCI6MjEwMjY2MzYyOX0.nAZASYlhS3OBFc-mBSUVenGUTuzfMZgcbt9eBhc4Dm4"

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
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

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
        let data = try await perform(request)

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

        _ = try await perform(request)
    }

    /// Delete a bar and its prices (prices cascade)
    func deleteBar(_ bar: Bar) async throws {

        let request = makeRequest(
            endpoint: "bars?id=eq.\(bar.id.uuidString)",
            method: "DELETE"
        )

        _ = try await perform(request)
    }

    // MARK: - Prices

    /// Fetch every price entry, mapped to domain Price models
    func fetchAllPrices() async throws -> [Price] {

        let request = makeRequest(endpoint: "prices?select=*")
        let data = try await perform(request)

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

        let data = try await perform(request)

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

        _ = try await perform(request)
    }

    /// Update an existing price entry
    func updatePrice(_ price: Price) async throws {

        var request = makeRequest(
            endpoint: "prices?id=eq.\(price.id.uuidString)",
            method: "PATCH"
        )

        let dto = PriceDTO(from: price)
        request.httpBody = try encoder.encode(dto)

        _ = try await perform(request)
    }

    /// Delete a price entry
    func deletePrice(_ price: Price) async throws {

        let request = makeRequest(
            endpoint: "prices?id=eq.\(price.id.uuidString)",
            method: "DELETE"
        )

        _ = try await perform(request)
    }

    // MARK: - Bar Ratings

    /// Fetch every ambience/wine rating, mapped to domain BarRating models
    func fetchBarRatings() async throws -> [BarRating] {

        let request = makeRequest(endpoint: "bar_ratings?select=*")
        let data = try await perform(request)

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

        _ = try await perform(request)
    }

    // MARK: - Drink Brands

    /// Fetch the shared, admin-approved brand catalog.
    func fetchBrands() async throws -> [DrinkBrand] {

        let request = makeRequest(endpoint: "drink_brands?select=*")
        let data = try await perform(request)

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

        _ = try await perform(request)
    }

    // MARK: - Brand Requests

    func fetchBrandRequests() async throws -> [BrandRequest] {

        let request = makeRequest(endpoint: "brand_requests?select=*")
        let data = try await perform(request)

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

        _ = try await perform(httpRequest)
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

        _ = try await perform(httpRequest)
    }
}