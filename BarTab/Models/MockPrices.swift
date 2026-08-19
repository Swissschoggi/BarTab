import Foundation

extension Price {

    static let mockPrices: [Price] = [

        Price(
            id: UUID(),
            barID: Bar.mockBars[0].id,
            drink: .beer,
            brand: "Feldschlösschen",
            size: .fiveDeciliters,
            amount: Decimal(string: "6.50")!,
            currency: "CHF",
            reportedAt: Date(),
            reportedBy: User.mockUser.id
        ),

        Price(
            id: UUID(),
            barID: Bar.mockBars[0].id,
            drink: .wine,
            brand: "Féchy",
            size: .oneDeciliter,
            amount: Decimal(string: "7.00")!,
            currency: "CHF",
            reportedAt: Date(),
            reportedBy: User.mockUser.id
        ),

        Price(
            id: UUID(),
            barID: Bar.mockBars[1].id,
            drink: .cocktail,
            brand: nil,
            size: .glass,
            amount: Decimal(string: "14.00")!,
            currency: "CHF",
            reportedAt: Date(),
            reportedBy: User.mockUser.id
        )
    ]
}
