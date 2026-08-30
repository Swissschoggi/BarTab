import Foundation

struct ActivityItem: Identifiable {
    let id: UUID
    let userID: UUID
    let kind: Kind
    let timestamp: Date
    let barID: UUID?

    enum Kind {
        case priceReport(barName: String, drink: String, amount: Decimal, currency: String)
        case barRating(barName: String, ambience: String?)
        case drinkRating(barName: String, drink: String, quality: Int)
        case barCreated(barName: String)
    }

    var icon: String {
        switch kind {
        case .priceReport: return "dollarsign.circle.fill"
        case .barRating: return "star.fill"
        case .drinkRating: return "wineglass.fill"
        case .barCreated: return "mappin.circle.fill"
        }
    }

    var actionText: String {
        switch kind {
        case .priceReport: return "reported a price"
        case .barRating: return "rated a bar"
        case .drinkRating: return "rated a drink"
        case .barCreated: return "added a bar"
        }
    }
}
