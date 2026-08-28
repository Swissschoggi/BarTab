import Foundation
import Combine
import CoreLocation

@MainActor
final class BarRepository: ObservableObject {

    @Published private(set) var bars: [Bar] = []
    @Published private(set) var prices: [Price] = []
    @Published private(set) var favoriteBarIDs: Set<UUID> = []
    @Published private(set) var reports: [ContentReport] = []
    @Published private(set) var barRatings: [BarRating] = []
    @Published private(set) var brands: [DrinkBrand] = DrinkBrand.all
    @Published private(set) var brandRequests: [BrandRequest] = []

    /// 1…4 dollar-sign level per bar, relative to the overall
    /// average drink price across all bars. Empty when unknown.
    @Published private(set) var priceLevelByBarID: [UUID: Int] = [:]

    /// When the last full fetch from Supabase completed.
    @Published private(set) var lastFetchedAt: Date?

    /// Optional toast sink so background failures surface as
    /// friendly banners instead of silent prints.
    private var toastCenter: ToastCenter?

    private static let favoritesKey = "com.bartab.favoriteBarIDs"

    func attachToastCenter(_ center: ToastCenter) {
        toastCenter = center
    }

    init() {
        loadFavoritesFromDisk()
        Task {
            await fetchAllData()
        }
    }

    // MARK: - Favorites Persistence

    private func loadFavoritesFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.favoritesKey),
              let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data)
        else { return }
        favoriteBarIDs = ids
    }

    private func saveFavoritesToDisk() {
        guard let data = try? JSONEncoder().encode(favoriteBarIDs) else { return }
        UserDefaults.standard.set(data, forKey: Self.favoritesKey)
    }

    // MARK: - Supabase Fetching

    func fetchAllData() async {
        do {
            async let fetchedBars = SupabaseClient.shared.fetchBars()
            async let fetchedPrices = SupabaseClient.shared.fetchAllPrices()
            async let fetchedRatings = SupabaseClient.shared.fetchBarRatings()
            async let fetchedDrinkRatings = SupabaseClient.shared.fetchAllDrinkRatings()
            async let fetchedBrands = SupabaseClient.shared.fetchBrands()
            async let fetchedBrandRequests = SupabaseClient.shared.fetchBrandRequests()
            async let fetchedReports = SupabaseClient.shared.fetchContentReports()

            self.bars = try await fetchedBars
            self.prices = try await fetchedPrices
            self.barRatings = try await fetchedRatings
            self.drinkRatings = try await fetchedDrinkRatings
            self.brandRequests = try await fetchedBrandRequests
            self.reports = try await fetchedReports

            // Merge the server-approved catalog with the bundled
            // defaults, so the app still has sensible brands to
            // offer even before the backend is seeded.
            let serverBrands = try await fetchedBrands
            var merged: [String: DrinkBrand] = [:]
            for brand in DrinkBrand.all + serverBrands {
                let key = "\(brand.drink.rawValue)|\(brand.name.lowercased())"
                merged[key] = brand
            }
            self.brands = Array(merged.values)
            recomputePriceLevels()
            self.lastFetchedAt = Date()
        } catch {
            print("Failed to fetch initial data: \(error)")
            toastCenter?.showError(error)
        }
    }

    func refreshReports() async {
        do {
            self.reports = try await SupabaseClient.shared.fetchContentReports()
        } catch {
            print("Failed to fetch reports: \(error)")
        }
    }

    func fetchPrices(for bar: Bar) async {
        do {
            let fetchedPrices = try await SupabaseClient.shared.fetchPrices(for: bar.id)

            // Merge or update local prices for this bar
            self.prices.removeAll { $0.barID == bar.id }
            self.prices.append(contentsOf: fetchedPrices)
            recomputePriceLevels()
        } catch {
            print("Failed to fetch prices for bar \(bar.id): \(error)")
        }
    }

    // MARK: - Bar Actions

    func addBar(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        smokingFriendly: Bool = false,
        outdoorSeating: Bool = false,
        createdBy user: User
    ) async -> Bar? {

        let bar = Bar(
            id: UUID(),
            name: name,
            address: address,
            coordinate: coordinate,
            createdAt: Date(),
            createdBy: user.id,
            smokingFriendly: smokingFriendly,
            outdoorSeating: outdoorSeating
        )

        do {
            try await SupabaseClient.shared.addBar(bar)
            self.bars.append(bar)
            return bar
        } catch {
            print("Failed to save bar to Supabase: \(error)")
            toastCenter?.showError(error)
            return nil
        }
    }

    func deleteBar(
        _ bar: Bar,
        createdBy user: User
    ) async {
        guard user.isAdmin || bar.createdBy == user.id else { return }

        do {
            try await SupabaseClient.shared.deleteBar(bar)
            self.bars.removeAll { $0.id == bar.id }
            self.prices.removeAll { $0.barID == bar.id }
            self.favoriteBarIDs.remove(bar.id)
            saveFavoritesToDisk()
            recomputePriceLevels()
        } catch {
            print("Failed to delete bar from Supabase: \(error)")
            toastCenter?.showError(error)
        }
    }

    func editBar(
        _ bar: Bar,
        name: String,
        address: String,
        smokingFriendly: Bool,
        outdoorSeating: Bool,
        editedBy user: User
    ) async {
        guard user.isAdmin || bar.createdBy == user.id else { return }

        let updated = Bar(
            id: bar.id,
            name: name,
            address: address,
            coordinate: bar.coordinate,
            createdAt: bar.createdAt,
            createdBy: bar.createdBy,
            smokingFriendly: smokingFriendly,
            outdoorSeating: outdoorSeating
        )

        do {
            try await SupabaseClient.shared.updateBar(updated)
            if let index = bars.firstIndex(where: { $0.id == bar.id }) {
                bars[index] = updated
            }
        } catch {
            print("Failed to update bar on Supabase: \(error)")
            toastCenter?.showError(error)
        }
    }

    // MARK: - Price Actions

    func addPrice(
        to bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        currency: String? = nil,
        style: String? = nil,
        serving: ServingMethod? = nil,
        reportedBy user: User
    ) async -> Bool {

        let price = Price(
            id: UUID(),
            barID: bar.id,
            drink: drink,
            brand: brand,
            size: size,
            amount: amount,
            currency: currency ?? Currency.defaultCurrency.rawValue,
            reportedAt: Date(),
            reportedBy: user.id,
            style: style,
            serving: serving
        )

        do {
            try await SupabaseClient.shared.addPrice(price)
            self.prices.append(price)
            recomputePriceLevels()
            return true
        } catch {
            print("Failed to add price to Supabase: \(error)")
            toastCenter?.showError(error)
            return false
        }
    }

    func deletePrice(
        _ price: Price,
        reportedBy user: User
    ) async {
        guard user.isAdmin || price.reportedBy == user.id else { return }

        do {
            try await SupabaseClient.shared.deletePrice(price)
            self.prices.removeAll { $0.id == price.id }
            recomputePriceLevels()
        } catch {
            print("Failed to delete price from Supabase: \(error)")
            toastCenter?.showError(error)
        }
    }

    func deletePriceGroup(
        for bar: Bar,
        drink: Drink,
        size: DrinkSize,
        brand: String?,
        deletedBy user: User
    ) async {
        let groupPrices = prices.filter {
            $0.barID == bar.id &&
                $0.drink == drink &&
                $0.size == size &&
                $0.brand == brand
        }

        guard !groupPrices.isEmpty else { return }

        guard user.isAdmin || groupPrices.allSatisfy({ price in
            price.reportedBy == user.id
        }) else {
            return
        }

        do {
            for price in groupPrices {
                try await SupabaseClient.shared.deletePrice(price)
            }
            self.prices.removeAll { price in
                groupPrices.contains { $0.id == price.id }
            }
            recomputePriceLevels()
        } catch {
            print("Failed to delete price group from Supabase: \(error)")
            toastCenter?.showError(error)
        }
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

        do {
            try await SupabaseClient.shared.updatePrice(updatedPrice)
            self.prices[index] = updatedPrice
            recomputePriceLevels()
        } catch {
            print("Failed to update price on Supabase: \(error)")
            toastCenter?.showError(error)
        }
    }

    // MARK: - Price Levels ($ signs)

    /// Average converted price of all drinks reported at this bar.
    func averageBarPrice(for bar: Bar) -> Decimal? {

        let amounts = getPriceSummaries(for: bar).map {
            NSDecimalNumber(decimal: $0.convertedAmount).doubleValue
        }

        guard !amounts.isEmpty else { return nil }

        return Decimal(amounts.reduce(0, +) / Double(amounts.count))
    }

    /// Dollar-sign level 1…4 for the bar, relative to the average
    /// drink price across every bar. Nil when there's no data yet.
    func priceLevel(for bar: Bar) -> String? {
        guard let level = priceLevelByBarID[bar.id] else { return nil }
        return String(repeating: "$", count: level)
    }

    private func recomputePriceLevels() {

        var totalsPerBar: [UUID: Double] = [:]
        var countsPerBar: [UUID: Int] = [:]

        var grandTotal = 0.0
        var grandCount = 0

        for bar in bars {
            let summaries = getPriceSummaries(for: bar)
            guard !summaries.isEmpty else { continue }

            let total = summaries.reduce(0.0) { partial, summary in
                partial + NSDecimalNumber(decimal: summary.convertedAmount).doubleValue
            }

            totalsPerBar[bar.id] = total
            countsPerBar[bar.id] = summaries.count
            grandTotal += total
            grandCount += summaries.count
        }

        guard grandCount > 0 else {
            priceLevelByBarID = [:]
            return
        }

        let globalAverage = grandTotal / Double(grandCount)

        var levels: [UUID: Int] = [:]
        for (barID, total) in totalsPerBar {
            let count = countsPerBar[barID] ?? 1
            let ratio = (total / Double(count)) / globalAverage

            switch ratio {
            case ..<0.8:
                levels[barID] = 1
            case ..<1.1:
                levels[barID] = 2
            case ..<1.4:
                levels[barID] = 3
            default:
                levels[barID] = 4
            }
        }

        priceLevelByBarID = levels
    }

    // MARK: - Bar Ratings

    func ratings(for bar: Bar) -> [BarRating] {
        barRatings.filter { $0.barID == bar.id }
    }

    /// Most common ambience style for a bar, or nil if nobody has rated it.
    func popularAmbience(for bar: Bar) -> AmbienceStyle? {
        let allStyles = ratings(for: bar).flatMap { $0.ambience }
        guard !allStyles.isEmpty else { return nil }
        var counts: [AmbienceStyle: Int] = [:]
        for style in allStyles {
            counts[style, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    func ambienceStyles(for bar: Bar) -> [AmbienceStyle] {
        let allStyles = ratings(for: bar).flatMap { $0.ambience }
        var counts: [AmbienceStyle: Int] = [:]
        for style in allStyles {
            counts[style, default: 0] += 1
        }
        return counts.sorted(by: { $0.value > $1.value }).map(\.key)
    }

    func ambienceCount(for bar: Bar) -> Int {
        ratings(for: bar).reduce(0) { $0 + $1.ambience.count }
    }

    /// Average wine-quality rating and how many people rated it, or
    /// nil if nobody has rated this bar's wine yet.
    func averageWineQuality(for bar: Bar) -> (average: Double, count: Int)? {
        let values = ratings(for: bar).compactMap { $0.wineQuality }
        guard !values.isEmpty else { return nil }
        return (Double(values.reduce(0, +)) / Double(values.count), values.count)
    }

    func myRating(for bar: Bar, by user: User) -> BarRating? {
        ratings(for: bar).first { $0.ratedBy == user.id }
    }

    /// Submits (or updates) the current user's ambience/wine rating
    /// for a bar. Passing nil for a dimension leaves it unrated.
    func submitRating(
        for bar: Bar,
        ambience: [AmbienceStyle],
        wineQuality: Int?,
        by user: User
    ) async {

        let existing = myRating(for: bar, by: user)

        let mergedAmbience: [AmbienceStyle] = {
            if ambience.isEmpty { return existing?.ambience ?? [] }
            return ambience
        }()

        let rating = BarRating(
            id: existing?.id ?? UUID(),
            barID: bar.id,
            ratedBy: user.id,
            ambience: mergedAmbience,
            wineQuality: wineQuality ?? existing?.wineQuality,
            createdAt: Date()
        )

        do {
            try await SupabaseClient.shared.upsertBarRating(rating)
            if let index = barRatings.firstIndex(where: { $0.id == rating.id }) {
                barRatings[index] = rating
            } else {
                barRatings.append(rating)
            }
        } catch {
            print("Failed to submit bar rating: \(error)")
            toastCenter?.showError(error)
        }
    }

    // MARK: - Drink Ratings (per product)

    @Published private(set) var drinkRatings: [DrinkRating] = []

    func drinkRatings(for bar: Bar) -> [DrinkRating] {
        drinkRatings.filter { $0.barID == bar.id }
    }

    /// Average quality rating for a specific drink product at a bar.
    func averageDrinkQuality(
        for bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize
    ) -> (average: Double, count: Int)? {
        let values = drinkRatings(for: bar).filter {
            $0.drink == drink && $0.brand == brand && $0.size == size
        }.map(\.quality)
        guard !values.isEmpty else { return nil }
        return (Double(values.reduce(0, +)) / Double(values.count), values.count)
    }

    /// The current user's rating for a specific drink product.
    func myDrinkRating(
        for bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        by user: User
    ) -> DrinkRating? {
        drinkRatings(for: bar).first {
            $0.drink == drink &&
            $0.brand == brand &&
            $0.size == size &&
            $0.ratedBy == user.id
        }
    }

    /// Submits or updates a drink product quality rating.
    func submitDrinkRating(
        for bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        quality: Int,
        by user: User
    ) async {
        let existing = myDrinkRating(
            for: bar, drink: drink, brand: brand, size: size, by: user
        )

        let rating = DrinkRating(
            id: existing?.id ?? UUID(),
            barID: bar.id,
            drink: drink,
            brand: brand,
            size: size,
            quality: quality,
            ratedBy: user.id,
            createdAt: Date()
        )

        do {
            try await SupabaseClient.shared.upsertDrinkRating(rating)
            if let index = drinkRatings.firstIndex(where: { $0.id == rating.id }) {
                drinkRatings[index] = rating
            } else {
                drinkRatings.append(rating)
            }
        } catch {
            print("Failed to submit drink rating: \(error)")
            toastCenter?.showError(error)
        }
    }

    // MARK: - Drink Brands

    func brands(for drink: Drink) -> [DrinkBrand] {
        brands
            .filter { $0.drink == drink }
            .sorted { $0.name < $1.name }
    }

    var pendingBrandRequestCount: Int {
        brandRequests.filter { $0.status == .pending }.count
    }

    func hasPendingRequest(
        name: String,
        for drink: Drink,
        by user: User
    ) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return brandRequests.contains {
            $0.drink == drink
            && $0.requestedBy == user.id
            && $0.status == .pending
            && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    /// Submits a request for a new brand. Does nothing if the brand
    /// already exists in the catalog or this user already has a
    /// pending request for it.
    func requestBrand(
        name: String,
        for drink: Drink,
        by user: User
    ) async {

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let alreadyExists = brands(for: drink).contains {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !alreadyExists else { return }
        guard !hasPendingRequest(name: trimmed, for: drink, by: user) else { return }

        let request = BrandRequest(
            id: UUID(),
            drink: drink,
            name: trimmed,
            requestedBy: user.id,
            requestedByName: user.username,
            status: .pending,
            createdAt: Date()
        )

        brandRequests.append(request)

        do {
            try await SupabaseClient.shared.submitBrandRequest(request)
        } catch {
            print("Failed to submit brand request: \(error)")
            toastCenter?.showError(error)
            brandRequests.removeAll { $0.id == request.id }
        }
    }

    /// Approves a brand request: adds it to the shared catalog and
    /// marks the request as approved. Only call this from
    /// admin-gated UI.
    func approveBrandRequest(_ request: BrandRequest) async {

        guard let index = brandRequests.firstIndex(where: { $0.id == request.id }) else {
            return
        }

        do {
            try await SupabaseClient.shared.insertBrand(
                drink: request.drink,
                name: request.name
            )
            try await SupabaseClient.shared.updateBrandRequestStatus(
                request.id,
                status: .approved
            )
            brandRequests[index].status = .approved
            let newBrand = DrinkBrand(
                id: UUID().uuidString,
                name: request.name,
                drink: request.drink
            )
            brands.append(newBrand)
        } catch {
            print("Failed to approve brand request: \(error)")
            toastCenter?.showError(error)
        }
    }

    /// Rejects a brand request. Only call this from admin-gated UI.
    func rejectBrandRequest(_ request: BrandRequest) async {

        guard let index = brandRequests.firstIndex(where: { $0.id == request.id }) else {
            return
        }

        do {
            try await SupabaseClient.shared.updateBrandRequestStatus(
                request.id,
                status: .rejected
            )
            brandRequests[index].status = .rejected
        } catch {
            print("Failed to reject brand request: \(error)")
            toastCenter?.showError(error)
        }
    }

    func deleteBrandRequest(_ request: BrandRequest) async {
        do {
            try await SupabaseClient.shared.deleteBrandRequest(request)
            brandRequests.removeAll { $0.id == request.id }
        } catch {
            print("Failed to delete brand request from Supabase: \(error)")
            toastCenter?.showError(error)
        }
    }

    func deleteReport(_ report: ContentReport) async {
        do {
            try await SupabaseClient.shared.deleteContentReport(report.id)
            reports.removeAll { $0.id == report.id }
        } catch {
            print("Failed to delete report from Supabase: \(error)")
            toastCenter?.showError(error)
        }
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
        saveFavoritesToDisk()
    }

    func toggleSmokingPolicy(for bar: Bar) async {
        guard let index = bars.firstIndex(where: { $0.id == bar.id }) else { return }
        let currentValue = bars[index].smokingFriendly
        let updated = Bar(
            id: bar.id,
            name: bar.name,
            address: bar.address,
            coordinate: bar.coordinate,
            createdAt: bar.createdAt,
            createdBy: bar.createdBy,
            smokingFriendly: !currentValue,
            outdoorSeating: bars[index].outdoorSeating
        )

        print("[BarRepository] PATCH smoking: bar=\(bar.id) \(bar.name) → \(updated.smokingFriendly)")
        do {
            try await SupabaseClient.shared.updateBar(updated)
            bars[index] = updated
            print("[BarRepository] PATCH smoking SUCCESS")
        } catch {
            print("[BarRepository] PATCH smoking FAILED: \(error)")
            toastCenter?.showError(error)
        }
    }

    func toggleOutdoorSeating(for bar: Bar) async {
        guard let index = bars.firstIndex(where: { $0.id == bar.id }) else { return }
        let currentValue = bars[index].outdoorSeating
        let updated = Bar(
            id: bar.id,
            name: bar.name,
            address: bar.address,
            coordinate: bar.coordinate,
            createdAt: bar.createdAt,
            createdBy: bar.createdBy,
            smokingFriendly: bars[index].smokingFriendly,
            outdoorSeating: !currentValue
        )

        print("[BarRepository] PATCH outdoor: bar=\(bar.id) \(bar.name) → \(updated.outdoorSeating)")
        do {
            try await SupabaseClient.shared.updateBar(updated)
            bars[index] = updated
            print("[BarRepository] PATCH outdoor SUCCESS")
        } catch {
            print("[BarRepository] PATCH outdoor FAILED: \(error)")
            toastCenter?.showError(error)
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
        style: String? = nil,
        serving: ServingMethod? = nil,
        reason: ReportReason,
        reportedBy user: User
    ) {
        var label = "\(drink.displayName) · \(size.displayName)"
        if let brand = brand {
            label += " (\(brand))"
        }
        if let style {
            label += " · \(style)"
        }

        addReport(
            targetID: priceGroupKey(drink: drink, size: size, brand: brand, style: style, serving: serving),
            targetType: .price,
            targetLabel: label,
            reason: reason,
            user: user
        )
    }

    func markReportReviewed(_ report: ContentReport) async {
        guard let index = reports.firstIndex(where: { $0.id == report.id }) else { return }

        let now = Date()
        do {
            try await SupabaseClient.shared.markContentReportReviewed(
                report.id,
                reviewedAt: now
            )
            reports[index].isReviewed = true
            reports[index].reviewedAt = now
        } catch {
            print("Failed to mark report reviewed on Supabase: \(error)")
            toastCenter?.showError(error)
        }
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

    func isPriceGroupFlagged(drink: Drink, size: DrinkSize, brand: String?, style: String? = nil, serving: ServingMethod? = nil) -> Bool {
        reportCount(for: priceGroupKey(drink: drink, size: size, brand: brand, style: style, serving: serving)) > 0
    }

    func reportCount(for targetID: String) -> Int {
        reports.filter { $0.targetID == targetID }.count
    }

    func priceGroupKey(drink: Drink, size: DrinkSize, brand: String?, style: String? = nil, serving: ServingMethod? = nil) -> String {
        "\(drink)-\(size)-\(brand ?? "")-\(style ?? "")-\(serving?.rawValue ?? "")"
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

        Task { [weak self] in
            do {
                try await SupabaseClient.shared.insertContentReport(report)
                // Re-fetch to get server-assigned fields (id, timestamp)
                await self?.refreshReports()
            } catch {
                print("Failed to save report to Supabase: \(error)")
                self?.toastCenter?.showError(error)
                self?.reports.removeAll { $0.id == report.id }
            }
        }
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
        let style = price.style ?? ""
        let serving = price.serving?.rawValue ?? ""
        return "\(price.drink)-\(price.size)-\(brand)-\(style)-\(serving)"
    }

    /// Find a bar that has a price matching this group key.
    func barForPriceGroupKey(_ key: String) -> Bar? {
        prices.first { priceGroupKey($0) == key }
            .flatMap { getBar(id: $0.barID) }
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
            confidence: confidence,
            style: first.style,
            serving: first.serving
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
