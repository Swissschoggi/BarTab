import Foundation

/// A user's quality rating for a specific drink product at a bar.
/// One row per (bar, drink, brand, size, user) combination.
struct DrinkRating: Identifiable {

    let id: UUID
    let barID: UUID
    let drink: Drink
    let brand: String?
    let size: DrinkSize
    let quality: Int
    let ratedBy: UUID
    let createdAt: Date
}
