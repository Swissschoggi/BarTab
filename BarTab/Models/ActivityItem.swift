import Foundation

enum ActivityItem: Identifiable {
    case priceReport(
        id: UUID,
        userID: UUID,
        barName: String,
        drink: String,
        amount: Decimal,
        currency: String,
        timestamp: Date
    )
    case barRating(
        id: UUID,
        userID: UUID,
        barName: String,
        ambience: String?,
        timestamp: Date
    )

    var id: UUID {
        switch self {
        case .priceReport(let id, _, _, _, _, _, _): return id
        case .barRating(let id, _, _, _, _): return id
        }
    }

    var timestamp: Date {
        switch self {
        case .priceReport(_, _, _, _, _, _, let t): return t
        case .barRating(_, _, _, _, let t): return t
        }
    }

    var userID: UUID {
        switch self {
        case .priceReport(_, let uid, _, _, _, _, _): return uid
        case .barRating(_, let uid, _, _, _): return uid
        }
    }
}
