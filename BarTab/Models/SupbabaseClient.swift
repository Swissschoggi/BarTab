import Foundation

final class SupabaseClient {
    static let shared = SupabaseClient()
    
    // Replace with your project details from Supabase Dashboard -> Settings -> API
    private let baseURL = "https://xdyewakhzjnmpzhzhehl.supabase.co"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhkeWV3YWtoempubXB6aHpoZWhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwODc2MjksImV4cCI6MjEwMjY2MzYyOX0.nAZASYlhS3OBFc-mBSUVenGUTuzfMZgcbt9eBhc4Dm4"
    
    private init() {}
    
    // MARK: - Headers & Requests
    
    private func makeRequest(endpoint: String, method: String = "GET") -> URLRequest {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if method == "POST" || method == "PATCH" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        
        return request
    }
    
    // MARK: - Date Handling
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let formatterStandard = ISO8601DateFormatter()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = formatterWithFractional.date(from: dateString) ?? formatterStandard.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date string: \(dateString)")
        }
        
        return decoder
    }
    
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        
        return encoder
    }
    
    // MARK: - API Methods
    
    /// Fetch all bars mapped to domain Bar models
    func fetchBars() async throws -> [Bar] {
        let request = makeRequest(endpoint: "bars?select=*")
        let (data, _) = try await URLSession.shared.data(for: request)
        let dtos = try decoder.decode([BarDTO].self, from: data)
        return dtos.map { $0.toDomain }
    }
    
    /// Add a new bar using Bar domain model
    func addBar(_ bar: Bar) async throws {
        var request = makeRequest(endpoint: "bars", method: "POST")
        let dto = BarDTO(from: bar)
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Fetch prices for a specific bar mapped to domain Price models
    func fetchPrices(for barID: UUID) async throws -> [Price] {
        let endpoint = "prices?bar_id=eq.\(barID.uuidString)&select=*"
        let request = makeRequest(endpoint: endpoint)
        let (data, _) = try await URLSession.shared.data(for: request)
        let dtos = try decoder.decode([PriceDTO].self, from: data)
        return dtos.compactMap { $0.toDomain }
    }
    
    /// Add a new price entry using Price domain model
    func addPrice(_ price: Price) async throws {
        var request = makeRequest(endpoint: "prices", method: "POST")
        let dto = PriceDTO(from: price)
        request.httpBody = try encoder.encode(dto)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
