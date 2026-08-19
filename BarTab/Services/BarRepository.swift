import Foundation
import Combine
import CoreLocation

final class BarRepository: ObservableObject {

    @Published private(set) var bars: [Bar] = []
    @Published private(set) var prices: [Price] = []
    @Published private(set) var favoriteBarIDs: Set<UUID> = []

    init() {
        loadMockData()
    }


    func getBars() -> [Bar] {
        bars
    }

    func getBar(id: UUID) -> Bar? {
        bars.first { $0.id == id }
    }

    func nearbyBars(
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) -> [Bar] {

        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        return bars.filter { bar in

            let barLocation = CLLocation(
                latitude: bar.coordinate.latitude,
                longitude: bar.coordinate.longitude
            )

            return location.distance(
                from: barLocation
            ) <= radius
        }
    }

    @discardableResult
    func addBar(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        createdBy user: User
    ) -> Bar {

        let bar = Bar(
            id: UUID(),
            name: name,
            address: address,
            coordinate: coordinate,
            createdAt: Date(),
            createdBy: user.id
        )

        bars.append(bar)

        return bar
    }


    func getPrices(for bar: Bar) -> [Price] {

        prices.filter { price in
            price.barID == bar.id
        }
    }

    var favoriteBars: [Bar] {
        bars.filter { bar in
            favoriteBarIDs.contains(bar.id)
        }
    }

    func isFavorite(_ bar: Bar) -> Bool {
        favoriteBarIDs.contains(bar.id)
    }

    func toggleFavorite(_ bar: Bar) {
        if favoriteBarIDs.contains(bar.id) {
            favoriteBarIDs.remove(bar.id)
        } else {
            favoriteBarIDs.insert(bar.id)
        }
    }

    func getPrices(reportedBy user: User) -> [Price] {

        prices.filter { price in
            price.reportedBy == user.id
        }
    }

    func addPrice(
        to bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        reportedBy user: User
    ) {

        let price = Price(
            id: UUID(),
            barID: bar.id,
            drink: drink,
            brand: brand,
            size: size,
            amount: amount,
            currency: "CHF",
            reportedAt: Date(),
            reportedBy: user.id
        )

        prices.append(price)
    }

    func deletePrice(
        _ price: Price,
        reportedBy user: User
    ) {

        guard price.reportedBy == user.id else {
            return
        }

        prices.removeAll {
            $0.id == price.id
        }
    }

    func deleteBar(
        _ bar: Bar,
        createdBy user: User
    ) {

        guard bar.createdBy == user.id else {
            return
        }

        bars.removeAll {
            $0.id == bar.id
        }

        prices.removeAll {
            $0.barID == bar.id
        }

        favoriteBarIDs.remove(bar.id)
    }

    func updatePrice(
        _ price: Price,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        reportedBy user: User
    ) {

        guard price.reportedBy == user.id else {
            return
        }

        guard let index = prices.firstIndex(
            where: { $0.id == price.id }
        ) else {
            return
        }

        let updatedPrice = Price(
            id: price.id,
            barID: price.barID,
            drink: drink,
            brand: brand,
            size: size,
            amount: amount,
            currency: price.currency,
            reportedAt: price.reportedAt,
            reportedBy: price.reportedBy
        )

        prices[index] = updatedPrice
    }


    private func loadMockData() {

        bars = Bar.mockBars
        prices = Price.mockPrices
    }

    func getPriceSummaries(for bar: Bar) -> [PriceSummary] {
        let barPrices = getPrices(for: bar)

        var groups: [
            String: [Price]
        ] = [:]

        for price in barPrices {
            let key = priceGroupKey(price)
            groups[key, default: []].append(price)
        }

        return groups.values.compactMap { reports in
            makePriceSummary(
                reports: reports,
                barID: bar.id
            )
        }
        .sorted {
            NSDecimalNumber(decimal: $0.amount).doubleValue <
            NSDecimalNumber(decimal: $1.amount).doubleValue
        }
    }

    private func priceGroupKey(_ price: Price) -> String {
        let brand = price.brand ?? ""

        return [
            price.drink.displayName,
            price.size.displayName,
            brand
        ]
        .joined(separator: "|")
    }

    private func makePriceSummary(
        reports: [Price],
        barID: UUID
    ) -> PriceSummary? {

        guard let first = reports.first else {
            return nil
        }

        let confidence = calculateConfidence(
            reports: reports
        )

        let sortedAmounts = reports
            .map {
                NSDecimalNumber(
                    decimal: $0.amount
                ).doubleValue
            }
            .sorted()

        let median: Double

        if sortedAmounts.count % 2 == 0 {
            let middle = sortedAmounts.count / 2

            median =
                (sortedAmounts[middle - 1] +
                 sortedAmounts[middle]) / 2
        } else {
            median =
                sortedAmounts[
                    sortedAmounts.count / 2
                ]
        }

        let amount = Decimal(median)

        return PriceSummary(
            id: first.id,
            barID: barID,
            drink: first.drink,
            brand: first.brand,
            size: first.size,
            amount: amount,
            currency: first.currency,
            reports: reports.sorted {
                $0.reportedAt > $1.reportedAt
            },
            confidence: confidence
        )
    }

    private func calculateConfidence(
        reports: [Price]
    ) -> Int {

        guard !reports.isEmpty else {
            return 0
        }

        let now = Date()

        let recentReports = reports.filter {
            now.timeIntervalSince($0.reportedAt)
                <= 365 * 24 * 60 * 60
        }

        guard !recentReports.isEmpty else {
            return 15
        }

        let reportScore = min(
            Double(recentReports.count) / 8.0,
            1.0
        )

        let recencyScore =
            recentReports.reduce(0.0) {
                total,
                report in

                let age =
                    max(
                        0,
                        now.timeIntervalSince(
                            report.reportedAt
                        )
                    )

                let days =
                    age / (24 * 60 * 60)

                let freshness =
                    max(
                        0.0,
                        1.0 - days / 365.0
                    )

                return total + freshness
            }
            / Double(recentReports.count)


        let amounts = recentReports.map {
            NSDecimalNumber(
                decimal: $0.amount
            ).doubleValue
        }

        let average =
            amounts.reduce(0, +)
            / Double(amounts.count)

        guard average > 0 else {
            return 0
        }

        let deviations = amounts.map {
            abs($0 - average)
        }

        let averageDeviation =
            deviations.reduce(0, +)
            / Double(deviations.count)

        let agreementScore =
            max(
                0.0,
                1.0 -
                averageDeviation / average
            )

        let score =
            reportScore * 0.45 +
            recencyScore * 0.30 +
            agreementScore * 0.25

        return Int(
            (score * 100).rounded()
        )
    }
    func confidenceForPrice(
        _ price: Price,
        at bar: Bar
    ) -> Int {
        let matchingPrices = getPrices(for: bar).filter {
            $0.drink == price.drink &&
            $0.size == price.size &&
            $0.brand == price.brand
        }

        guard !matchingPrices.isEmpty else {
            return 0
        }

        let now = Date()

        // Only consider reports from the last year.
        let recentPrices = matchingPrices.filter {
            now.timeIntervalSince($0.reportedAt) <= 365 * 24 * 60 * 60
        }

        guard !recentPrices.isEmpty else {
            return 20
        }

        let reportScore = min(
            Double(recentPrices.count) / 8.0,
            1.0
)
        let recencyScore = recentPrices.reduce(0.0) {
            partial,
            reportedPrice in

            let age = now.timeIntervalSince(
                reportedPrice.reportedAt
            )

            let days = age / (24 * 60 * 60)

            let freshness = max(
                0.0,
                1.0 - days / 365.0
            )

            return partial + freshness
        } / Double(recentPrices.count)

        let amounts = recentPrices.map {
            NSDecimalNumber(
                decimal: $0.amount
            ).doubleValue
        }

        let average =
            amounts.reduce(0, +) /
            Double(amounts.count)

        let deviations = amounts.map {
            abs($0 - average)
        }

        let averageDeviation =
            deviations.reduce(0, +) /
            Double(deviations.count)

        let agreementScore = max(
            0.0,
            1.0 -
            averageDeviation /
            max(average, 1.0)
        )

        let score =
            reportScore * 0.45 +
            recencyScore * 0.30 +
            agreementScore * 0.25

        return Int(
            (score * 100).rounded()
        )
    }

}
