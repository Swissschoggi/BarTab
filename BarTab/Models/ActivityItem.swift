import Foundation

struct ActivityItem: Identifiable {
    let id: UUID
    let userID: UUID
    let kind: Kind
    let timestamp: Date

    enum Kind {
        case priceReport(barName: String, drink: String, amount: Decimal, currency: String)
        case barRating(barName: String, ambience: String?)
    }

    var icon: String {
        switch kind {
        case .priceReport: return "dollarsign.circle.fill"
        case .barRating: return "star.fill"
        }
    }

    var actionText: String {
        switch kind {
        case .priceReport: return "reported a price"
        case .barRating: return "rated a bar"
        }
    }
}
