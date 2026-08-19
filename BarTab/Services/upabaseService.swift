import Foundation

final class SupabaseService {
    
    static let shared = SupabaseService()
    private init() {}

    // Replace these with your Supabase Project details
    private let baseURL = "https://YOUR-PROJECT-REF.supabase.co/rest/v1"
    private let apiKey = "YOUR-ANON-KEY"

    // Helper to configure standard Supabase headers
    private func makeRequest(endpoint: String, method: String = "GET") -> URLRequest {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // 1. Fetch Bars
    func fetchBars() async throws -> [Bar] {
        let request = makeRequest(endpoint: "bars?select=*")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([BarDTO].self, from: data)
        return dtos.map { $0.toDomain }    }

    // 2. Add a Price Log
    func addPrice(
        barID: UUID,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        userID: UUID
    ) async throws {
        var request = makeRequest(endpoint: "prices", method: "POST")
        
        let body: [String: Any] = [
            "bar_id": barID.uuidString,
            "drink": drink.rawValue,
            "brand": brand as Any,
            "size": size.rawValue,
            "amount": amount,
            "reported_by": userID.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
