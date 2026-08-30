import Foundation

struct PriceAlert: Identifiable, Codable {
    let id: UUID
    let userID: UUID
    let barID: UUID
    let drink: String
    let size: String
    let brand: String?
    let targetPrice: Double?
    let isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID      = "user_id"
        case barID       = "bar_id"
        case drink, size, brand
        case targetPrice = "target_price"
        case isActive    = "is_active"
        case createdAt   = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        barID = try container.decode(UUID.self, forKey: .barID)
        drink = try container.decode(String.self, forKey: .drink)
        size = try container.decode(String.self, forKey: .size)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // numeric columns come back as strings from PostgREST
        if let doubleVal = try? container.decode(Double.self, forKey: .targetPrice) {
            targetPrice = doubleVal
        } else if let strVal = try? container.decode(String.self, forKey: .targetPrice) {
            targetPrice = Double(strVal)
        } else {
            targetPrice = nil
        }
    }
}
