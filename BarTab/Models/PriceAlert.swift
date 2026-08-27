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
}
