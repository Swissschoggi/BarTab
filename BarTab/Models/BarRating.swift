import Foundation

/// A single user's rating of a bar. A user may rate ambience
/// and wine quality   one row per (bar, user) pair, which
/// is upserted whenever they change their rating.
struct BarRating: Identifiable {

    let id: UUID
    let barID: UUID
    let ratedBy: UUID

    /// The ambience styles chosen by this user, empty if not rated.
    let ambience: [AmbienceStyle]

    /// 1...5, nil if this user hasn't rated the wine selection.
    let wineQuality: Int?

    let createdAt: Date
}
