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

    /// Always formatted with exactly two decimal places.
    var formattedAmount: String {
        amount.formattedAmount
    }

    /// Price normalized to a standard 10 cl serving (in the default
    /// currency). Used for fair "price level" comparisons where a bottle
    /// should not be compared directly against a glass. Nil when the size
    /// has no estimable volume.
    var normalizedAmountPer10cl: Double? {
        guard let volume = size.volumeInCentiliters(for: drink),
              volume > 0 else { return nil }

        let amount = NSDecimalNumber(decimal: convertedAmount).doubleValue
        return amount / (volume / 10)
    }

    /// Human-readable "per 10 cl" value, e.g. "4.50". Nil when the size
    /// has no estimable volume.
    var formattedNormalizedAmountPer10cl: String? {
        guard let normalized = normalizedAmountPer10cl else { return nil }
        return Decimal(normalized).formattedAmount
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
