import Foundation
import Combine
import CoreLocation

@MainActor
final class BarRepository: ObservableObject {

    @Published private(set) var bars: [Bar] = []
    @Published private(set) var prices: [Price] = []
    @Published private(set) var favoriteBarIDs: Set<UUID> = []
    @Published private(set) var reports: [ContentReport] = []

    init() {
        Task {
            await fetchAllData()
        }
    }

    // MARK: - Supabase Fetching

    func fetchAllData() async {
        do {
            async let fetchedBars = SupabaseClient.shared.fetchBars()
            // If you added fetchPrices to SupabaseClient, fetch all or query per bar
            self.bars = try await fetchedBars
        } catch {
            print("Failed to fetch initial data: \(error)")
        }
    }

    func fetchPrices(for bar: Bar) async {
        do {
            let fetchedPrices = try await SupabaseClient.shared.fetchPrices(for: bar.id)
            
            // Merge or update local prices for this bar
            self.prices.removeAll { $0.barID == bar.id }
            self.prices.append(contentsOf: fetchedPrices)
        } catch {
            print("Failed to fetch prices for bar \(bar.id): \(error)")
        }
    }

    // MARK: - Bar Actions

    func addBar(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        createdBy user: User
    ) async -> Bar? {

        let bar = Bar(
            id: UUID(),
            name: name,
            address: address,
            coordinate: coordinate,
            createdAt: Date(),
            createdBy: user.id
        )

        do {
            try await SupabaseClient.shared.addBar(bar)
            self.bars.append(bar)
            return bar
        } catch {
            print("Failed to save bar to Supabase: \(error)")
            return nil
        }
    }

    func deleteBar(
        _ bar: Bar,
        createdBy user: User
    ) async {
        guard bar.createdBy == user.id else { return }

        // Remove locally first or after server confirmation
        self.bars.removeAll { $0.id == bar.id }
        self.prices.removeAll { $0.barID == bar.id }
        self.favoriteBarIDs.remove(bar.id)
        
        // Add a DELETE endpoint method in SupabaseClient if needed
    }

    // MARK: - Price Actions

    func addPrice(
        to bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        reportedBy user: User
    ) async {

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

        do {
            try await SupabaseClient.shared.addPrice(price)
            self.prices.append(price)
        } catch {
            print("Failed to add price to Supabase: \(error)")
        }
    }

    func deletePrice(
        _ price: Price,
        reportedBy user: User
    ) async {
        guard price.reportedBy == user.id else { return }
        self.prices.removeAll { $0.id == price.id }
    }

    func updatePrice(
        _ price: Price,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        reportedBy user: User
    ) async {
        guard price.reportedBy == user.id else { return }
        guard let index = prices.firstIndex(where: { $0.id == price.id }) else { return }

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

        self.prices[index] = updatedPrice
    }

    // MARK: - Synchronous Read & Helper Methods
    // (Keep calculations like getPriceSummaries, calculateConfidence, and nearbyBars unchanged)

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
            return location.distance(from: barLocation) <= radius
        }
    }

    func getPrices(for bar: Bar) -> [Price] {
        prices.filter { $0.barID == bar.id }
    }

    var favoriteBars: [Bar] {
        bars.filter { favoriteBarIDs.contains($0.id) }
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
        prices.filter { $0.reportedBy == user.id }
    }

    // MARK: - Reporting & Summaries

    func reportBar(
        _ bar: Bar,
        reason: ReportReason,
        reportedBy user: User
    ) {
        addReport(
            targetID: bar.id.uuidString,
            targetType: .bar,
            targetLabel: bar.name,
            reason: reason,
            user: user
        )
    }

    func reportPriceGroup(
        drink: Drink,
        size: DrinkSize,
        brand: String?,
        reason: ReportReason,
        reportedBy user: User
    ) {
        var label = "\(drink.displayName) · \(size.displayName)"
        if let brand = brand {
            label += " (\(brand))"
        }

        addReport(
            targetID: priceGroupKey(drink: drink, size: size, brand: brand),
            targetType: .price,
            targetLabel: label,
            reason: reason,
            user: user
        )
    }

    func markReportReviewed(_ report: ContentReport) {
        guard let index = reports.firstIndex(where: { $0.id == report.id }) else { return }
        reports[index].isReviewed = true
        reports[index].reviewedAt = Date()
    }

    var unreviewedReportCount: Int {
        reports.filter { !$0.isReviewed }.count
    }

    func hasReported(_ targetID: String, by user: User) -> Bool {
        reports.contains { $0.targetID == targetID && $0.reportedBy == user.id }
    }

    func isBarFlagged(_ bar: Bar) -> Bool {
        reportCount(for: bar.id.uuidString) > 0
    }

    func isPriceGroupFlagged(drink: Drink, size: DrinkSize, brand: String?) -> Bool {
        reportCount(for: priceGroupKey(drink: drink, size: size, brand: brand)) > 0
    }

    func reportCount(for targetID: String) -> Int {
        reports.filter { $0.targetID == targetID }.count
    }

    func priceGroupKey(drink: Drink, size: DrinkSize, brand: String?) -> String {
        "\(drink)-\(size)-\(brand ?? "")"
    }

    private func addReport(
        targetID: String,
        targetType: ReportTargetType,
        targetLabel: String,
        reason: ReportReason,
        user: User
    ) {
        guard !reports.contains(where: { $0.targetID == targetID && $0.targetType == targetType && $0.reportedBy == user.id }) else { return }

        let report = ContentReport(
            id: UUID(),
            targetID: targetID,
            targetType: targetType,
            targetLabel: targetLabel,
            reason: reason,
            reportedBy: user.id,
            reportedByName: user.username,
            reportedAt: Date(),
            isReviewed: false,
            reviewedAt: nil
        )

        reports.append(report)
        ReportNotificationService.schedule(for: report)
    }

    func getPriceSummaries(for bar: Bar) -> [PriceSummary] {
        let barPrices = getPrices(for: bar)
        var groups: [String: [Price]] = [:]

        for price in barPrices {
            let key = priceGroupKey(price)
            groups[key, default: []].append(price)
        }

        return groups.values.compactMap { reports in
            makePriceSummary(reports: reports, barID: bar.id)
        }
        .sorted {
            NSDecimalNumber(decimal: $0.amount).doubleValue < NSDecimalNumber(decimal: $1.amount).doubleValue
        }
    }

    private func priceGroupKey(_ price: Price) -> String {
        let brand = price.brand ?? ""
        return [price.drink.displayName, price.size.displayName, brand].joined(separator: "|")
    }

    private func makePriceSummary(reports: [Price], barID: UUID) -> PriceSummary? {
        guard let first = reports.first else { return nil }

        let confidence = calculateConfidence(reports: reports)
        let sortedAmounts = reports.map { NSDecimalNumber(decimal: $0.amount).doubleValue }.sorted()

        let median: Double
        if sortedAmounts.count % 2 == 0 {
            let middle = sortedAmounts.count / 2
            median = (sortedAmounts[middle - 1] + sortedAmounts[middle]) / 2
        } else {
            median = sortedAmounts[sortedAmounts.count / 2]
        }

        return PriceSummary(
            id: first.id,
            barID: barID,
            drink: first.drink,
            brand: first.brand,
            size: first.size,
            amount: Decimal(median),
            currency: first.currency,
            reports: reports.sorted { $0.reportedAt > $1.reportedAt },
            confidence: confidence
        )
    }

    private func calculateConfidence(reports: [Price]) -> Int {
        guard !reports.isEmpty else { return 0 }
        let now = Date()
        let recentReports = reports.filter { now.timeIntervalSince($0.reportedAt) <= 365 * 24 * 60 * 60 }
        guard !recentReports.isEmpty else { return 15 }

        let reportScore = min(Double(recentReports.count) / 8.0, 1.0)
        let recencyScore = recentReports.reduce(0.0) { total, report in
            let age = max(0, now.timeIntervalSince(report.reportedAt))
            let days = age / (24 * 60 * 60)
            let freshness = max(0.0, 1.0 - days / 365.0)
            return total + freshness
        } / Double(recentReports.count)

        let amounts = recentReports.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
        let average = amounts.reduce(0, +) / Double(amounts.count)
        guard average > 0 else { return 0 }

        let deviations = amounts.map { abs($0 - average) }
        let averageDeviation = deviations.reduce(0, +) / Double(deviations.count)
        let agreementScore = max(0.0, 1.0 - averageDeviation / average)

        let score = reportScore * 0.45 + recencyScore * 0.30 + agreementScore * 0.25
        return Int((score * 100).rounded())
    }
}
