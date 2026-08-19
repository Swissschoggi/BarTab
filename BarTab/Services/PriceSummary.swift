import Foundation

struct PriceSummary: Identifiable {
    let id: UUID
    let barID: UUID
    let drink: Drink
    let brand: String?
    let size: DrinkSize
    let amount: Decimal
    let currency: String
    let reports: [Price]
    let confidence: Int

    var reportCount: Int {
        reports.count
    }

    var latestReportDate: Date? {
        reports.map(\.reportedAt).max()
    }

    var confidenceLabel: String {
        switch confidence {
        case 80...:
            return "High confidence"
        case 60..<80:
            return "Good confidence"
        case 40..<60:
            return "Moderate confidence"
        default:
            return "Low confidence"
        }
    }
}
