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
            return String(localized: "High confidence")
        case 60..<80:
            return String(localized: "Good confidence")
        case 40..<60:
            return String(localized: "Moderate confidence")
        default:
            return String(localized: "Low confidence")
        }
    }
}
