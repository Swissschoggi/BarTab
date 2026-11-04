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
    let style: String?
    let serving: ServingMethod?

    var reportCount: Int {
        reports.count
    }

    var latestReportDate: Date? {
        reports.map(\.reportedAt).max()
    }

    /// Volume in decilitres for volume-based sizes, nil otherwise.
    var volumeInDeciliters: Double? {
        switch size {
        case .oneDeciliter: return 1
        case .twoDeciliters: return 2
        case .threeDeciliters: return 3
        case .fiveDeciliters: return 5
        case .twentyCentiliters: return 2
        case .twentyFiveCentiliters: return 2.5
        case .thirtyThreeCentiliters: return 3.3
        case .fiftyCentiliters: return 5
        default: return nil
        }
    }

    /// Price per decilitre in the default currency (best value).
    var pricePerDeciliter: Double? {
        guard let volume = volumeInDeciliters, volume > 0 else { return nil }
        return NSDecimalNumber(decimal: convertedAmount).doubleValue / volume
    }

    /// Whether this price is older than 30 days and should be re-verified.
    var isStale: Bool {
        guard let date = latestReportDate else { return true }
        return date < Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }

    /// The amount converted to the user's default currency.
    var convertedAmount: Decimal {
        ExchangeRateService.shared.convert(
            amount,
            from: currency,
            to: Currency.defaultCurrency.rawValue
        )
    }

    /// Always formatted with exactly two decimal places.
    var formattedAmount: String {
        amount.formattedAmount
    }

    var formattedConvertedAmount: String {
        convertedAmount.formattedAmount
    }

    /// Whether this price is in a different currency than the default.
    var isConverted: Bool {
        currency != Currency.defaultCurrency.rawValue
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
