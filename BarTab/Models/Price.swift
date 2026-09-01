import Foundation

struct Price: Identifiable {

    let id: UUID
    let barID: UUID
    let drink: Drink
    let brand: String?
    let size: DrinkSize
    let amount: Decimal
    let currency: String
    let reportedAt: Date
    let reportedBy: UUID
    let style: String?
    let serving: ServingMethod?

    init(
        id: UUID,
        barID: UUID,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        currency: String,
        reportedAt: Date,
        reportedBy: UUID,
        style: String? = nil,
        serving: ServingMethod? = nil
    ) {
        self.id = id
        self.barID = barID
        self.drink = drink
        self.brand = brand
        self.size = size
        self.amount = amount
        self.currency = currency
        self.reportedAt = reportedAt
        self.reportedBy = reportedBy
        self.style = style
        self.serving = serving
    }

    /// Always formatted with exactly two decimal places.
    var formattedAmount: String {
        amount.formattedAmount
    }
}

/// A user's "still accurate" confirmation for a price.
struct PriceVerification: Identifiable, Codable {
    let id: UUID
    let priceID: UUID
    let userID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case priceID = "price_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

/// A user's "I'm here now" check-in at a bar.
struct BarCheckin: Identifiable, Codable {
    let id: UUID
    let barID: UUID
    let userID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case barID = "bar_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }
}
