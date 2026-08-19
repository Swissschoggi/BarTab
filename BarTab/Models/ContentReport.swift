import Foundation

enum ReportTargetType {
    case bar
    case price
}

enum ReportReason: String, CaseIterable, Identifiable {

    case wrongBar
    case notReal
    case spam
    case wrongPrice
    case priceOutdated
    case inappropriate

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .wrongBar:
            return "Wrong place"

        case .notReal:
            return "Doesn't exist"

        case .spam:
            return "Spam"

        case .wrongPrice:
            return "Wrong price"

        case .priceOutdated:
            return "Price is outdated"

        case .inappropriate:
            return "Inappropriate content"
        }
    }
}

struct ContentReport: Identifiable {

    let id: UUID
    let targetID: String
    let targetType: ReportTargetType
    let targetLabel: String
    let reason: ReportReason
    let reportedBy: UUID
    let reportedByName: String
    let reportedAt: Date
    var isReviewed: Bool
    var reviewedAt: Date?
}