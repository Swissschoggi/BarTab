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

    var formattedAmount: String {
        NSDecimalNumber(decimal: amount)
            .description(withLocale: Locale(identifier: "de_CH"))
    }
}
