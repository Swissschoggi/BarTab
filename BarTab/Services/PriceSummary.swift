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

    /// The amount converted to the user's default currency.
    var convertedAmount: Decimal {
        ExchangeRateService.shared.convert(
            amount,
            from: currency,
            to: Currency.defaultCurrency.rawValue
        )
    }

    var formattedAmount: String {
        NSDecimalNumber(decimal: amount)
            .description(withLocale: Locale(identifier: "de_CH"))
    }

    var formattedConvertedAmount: String {
        NSDecimalNumber(decimal: convertedAmount)
            .description(withLocale: Locale(identifier: "de_CH"))
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
