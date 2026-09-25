import Foundation

/// A permanent "stamp" in the beer passport: one row per distinct bar
/// a user has visited, with visit count and first/last visit times.
struct BarVisit: Identifiable, Codable {
    let userID: UUID
    let barID: UUID
    let firstVisitedAt: Date
    let lastVisitedAt: Date
    let visitCount: Int

    var id: String { "\(userID)-\(barID)" }

    enum CodingKeys: String, CodingKey {
        case userID         = "user_id"
        case barID          = "bar_id"
        case firstVisitedAt = "first_visited_at"
        case lastVisitedAt  = "last_visited_at"
        case visitCount     = "visit_count"
    }
}
