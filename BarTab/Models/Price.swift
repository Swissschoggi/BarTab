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
}
