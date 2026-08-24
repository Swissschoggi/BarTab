import Foundation

/// A single user's rating of a bar. A user may rate ambience,
/// wine quality, or both — one row per (bar, user) pair, which
/// is upserted whenever they change their rating.
struct BarRating: Identifiable {

    let id: UUID
    let barID: UUID
    let ratedBy: UUID

    /// 1...5, nil if this user hasn't rated ambience.
    let ambience: Int?

    /// 1...5, nil if this user hasn't rated the wine selection.
    let wineQuality: Int?

    let createdAt: Date
}
