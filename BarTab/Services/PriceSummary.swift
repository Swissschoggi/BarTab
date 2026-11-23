import Foundation
import CoreLocation

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

    /// Standard volume in millilitres for volume-based sizes, nil otherwise.
    var volumeInMilliliters: Int? {
        size.volumeInMilliliters
    }

    /// Volume in decilitres for volume-based sizes, nil otherwise.
    var volumeInDeciliters: Double? {
        size.volumeInDeciliters
    }

    /// Price per 100 ml in the default currency. This is the same as the
    /// price per decilitre (1 dl = 100 ml) and makes 3 dl / 5 dl servings
    /// directly comparable.
    var pricePer100ml: Double? {
        guard let milliliters = volumeInMilliliters, milliliters > 0 else {
            return nil
        }
        let converted = convertedAmount * 100 / Decimal(milliliters)
        return NSDecimalNumber(decimal: converted).doubleValue
    }

    /// Backwards-compatible alias used by the "best value" sort.
    var pricePerDeciliter: Double? {
        pricePer100ml
    }

    var formattedPricePer100ml: String? {
        guard let milliliters = volumeInMilliliters, milliliters > 0 else {
            return nil
        }
        let converted = convertedAmount * 100 / Decimal(milliliters)
        return PriceFormatting.per100ml(
            converted,
            currency: Currency.defaultCurrency.rawValue
        )
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

// MARK: - Formatting

enum PriceFormatting {

    /// e.g. "CHF 1.60 / 100 ml".
    static func per100ml(_ amount: Decimal, currency: String) -> String {
        let symbol = Currency(rawValue: currency)?.symbol ?? currency
        return "\(symbol)\(amount.formattedAmount) / 100 ml"
    }
}

// MARK: - Input parsing & validation

enum PriceInput {

    /// Parses a typed price, accepting both "5.50" and "5,50" (and
    /// common thousands separators) regardless of the device locale.
    static func parseAmount(_ text: String) -> Decimal? {
        guard !text.contains("-") else { return nil }

        let cleaned = text.filter { character in
            character.isNumber || character == "." || character == ","
        }
        guard cleaned.contains(where: { $0.isNumber }) else { return nil }

        let lastDot = cleaned.lastIndex(of: ".")
        let lastComma = cleaned.lastIndex(of: ",")

        let normalized: String
        if let lastDot, let lastComma {
            if lastDot > lastComma {
                // 1,234.56
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            } else {
                // 1.234,56
                normalized = cleaned
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            }
        } else if cleaned.contains(",") {
            let parts = cleaned.split(separator: ",")
            if parts.count == 2 {
                normalized = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if cleaned.contains(".") {
            let parts = cleaned.split(separator: ".")
            if parts.count > 2 {
                normalized = cleaned.replacingOccurrences(of: ".", with: "")
            } else {
                normalized = cleaned
            }
        } else {
            normalized = cleaned
        }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// A price must be positive and within a broad, sane upper bound.
    static func isValidAmount(_ amount: Decimal) -> Bool {
        amount > 0 && amount <= 10_000
    }

    /// Rounds to whole cents so tiny floating-point artefacts never get
    /// written to the database.
    static func roundedToCents(_ amount: Decimal) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}

// MARK: - Suspicious submission detection

enum PriceSanity {

    struct Issue: Identifiable, Equatable {
        let id: String
        let message: String
    }

    /// Flags submissions that are likely typos without blocking the user:
    /// extreme absolute values, implausible per-volume prices, or a price
    /// far away from several existing reports for the same drink/size.
    static func issues(
        amount: Decimal,
        currency: String,
        size: DrinkSize,
        drink: Drink,
        existingPrices: [Price]
    ) -> [Issue] {
        var issues: [Issue] = []

        let chfAmount = ExchangeRateService.shared.convert(
            amount,
            from: currency,
            to: "CHF"
        )
        let chfValue = NSDecimalNumber(decimal: chfAmount).doubleValue

        if chfValue < 0.20 {
            issues.append(Issue(
                id: "too-low",
                message: String(localized: "That price looks very low. Double-check the amount.")
            ))
        }

        if chfValue > 500 {
            issues.append(Issue(
                id: "too-high",
                message: String(localized: "That price looks unusually high. Double-check the amount.")
            ))
        }

        if let milliliters = size.volumeInMilliliters, milliliters > 0 {
            let per100ml = chfValue * 100 / Double(milliliters)
            if per100ml > 80 {
                issues.append(Issue(
                    id: "high-per-volume",
                    message: String(localized: "That works out to an unusually high price per 100 ml.")
                ))
            }
        }

        let comparable = existingPrices.filter {
            $0.drink == drink && $0.size == size
        }
        if comparable.count >= 2 {
            let values = comparable
                .map {
                    NSDecimalNumber(decimal: ExchangeRateService.shared.convert(
                        $0.amount,
                        from: $0.currency,
                        to: "CHF"
                    )).doubleValue
                }
                .sorted()
            let median: Double
            if values.count % 2 == 0 {
                let middle = values.count / 2
                median = (values[middle - 1] + values[middle]) / 2
            } else {
                median = values[values.count / 2]
            }

            if median > 0, chfValue > median * 3 || chfValue < median / 3 {
                issues.append(Issue(
                    id: "outlier",
                    message: String(localized: "This is far from other recent reports for the same drink. Please check it before submitting.")
                ))
            }
        }

        return issues
    }
}

// MARK: - Area coverage

enum AreaCoverage {

    struct Area: Identifiable {
        let name: String
        let barCount: Int
        let barsWithPrices: Int
        let priceCount: Int
        let missingBars: [Bar]

        var id: String { name }

        var coverage: Double {
            guard barCount > 0 else { return 0 }
            return Double(barsWithPrices) / Double(barCount)
        }

        var needsHelp: Bool {
            barsWithPrices == 0 || coverage < 0.75
        }
    }

    struct Summary {
        let totalBars: Int
        let barsWithPrices: Int
        let priceCount: Int
        let areas: [Area]
        let missingBars: [Bar]

        var coverage: Double {
            guard totalBars > 0 else { return 0 }
            return Double(barsWithPrices) / Double(totalBars)
        }

        var areasWithGoodCoverage: [Area] {
            areas.filter { $0.barsWithPrices > 0 && $0.coverage >= 0.75 }
        }

        var areasNeedingHelp: [Area] {
            areas.filter(\.needsHelp)
        }
    }

    /// Groups bars by the most specific part of their address we can
    /// reliably read (usually postal code + city, e.g. "8004 Zürich").
    /// No external geocoding service is needed.
    static func areaName(for bar: Bar) -> String {
        let parts = bar.address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let last = parts.last else { return String(localized: "Nearby") }

        let countryNames: Set<String> = [
            "switzerland", "schweiz", "suisse", "svizzera",
            "germany", "deutschland", "austria", "österreich",
            "france", "italy", "italia", "netherlands",
            "united kingdom", "uk"
        ]

        if countryNames.contains(last.lowercased()), parts.count >= 2 {
            return parts[parts.count - 2]
        }

        return last
    }

    static func build(
        bars: [Bar],
        prices: [Price],
        center: CLLocationCoordinate2D? = nil,
        radius: CLLocationDistance? = nil
    ) -> Summary {
        let relevantBars: [Bar]
        if let center, let radius {
            let origin = CLLocation(
                latitude: center.latitude,
                longitude: center.longitude
            )
            relevantBars = bars.filter { bar in
                let location = CLLocation(
                    latitude: bar.coordinate.latitude,
                    longitude: bar.coordinate.longitude
                )
                return origin.distance(from: location) <= radius
            }
        } else {
            relevantBars = bars
        }

        let barIDs = Set(relevantBars.map(\.id))
        let relevantPrices = prices.filter { barIDs.contains($0.barID) }

        var groupsByBar: [UUID: Set<String>] = [:]
        for price in relevantPrices {
            let key = [
                price.drink.rawValue,
                price.size.rawValue,
                price.brand ?? "",
                price.style ?? "",
                price.serving?.rawValue ?? ""
            ].joined(separator: "|")
            groupsByBar[price.barID, default: []].insert(key)
        }

        let barsWithPrices = relevantBars.filter {
            !(groupsByBar[$0.id]?.isEmpty ?? true)
        }

        let grouped = Dictionary(grouping: relevantBars) {
            areaName(for: $0)
        }

        let sortedMissing = sortedByDistance(
            relevantBars.filter { groupsByBar[$0.id]?.isEmpty ?? true },
            from: center
        )

        let areas = grouped.map { name, areaBars -> Area in
            let withPrices = areaBars.filter {
                !(groupsByBar[$0.id]?.isEmpty ?? true)
            }
            let priceCount = areaBars.reduce(0) {
                $0 + (groupsByBar[$1.id]?.count ?? 0)
            }
            let missing = sortedByDistance(
                areaBars.filter { groupsByBar[$0.id]?.isEmpty ?? true },
                from: center
            )
            return Area(
                name: name,
                barCount: areaBars.count,
                barsWithPrices: withPrices.count,
                priceCount: priceCount,
                missingBars: missing
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return Summary(
            totalBars: relevantBars.count,
            barsWithPrices: barsWithPrices.count,
            priceCount: groupsByBar.values.reduce(0) { $0 + $1.count },
            areas: areas,
            missingBars: sortedMissing
        )
    }

    private static func sortedByDistance(
        _ bars: [Bar],
        from center: CLLocationCoordinate2D?
    ) -> [Bar] {
        guard let center else {
            return bars.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let origin = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )
        return bars.sorted { lhs, rhs in
            let left = origin.distance(from: CLLocation(
                latitude: lhs.coordinate.latitude,
                longitude: lhs.coordinate.longitude
            ))
            let right = origin.distance(from: CLLocation(
                latitude: rhs.coordinate.latitude,
                longitude: rhs.coordinate.longitude
            ))
            return left < right
        }
    }
}
