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
    @Published private(set) var priceVerifications: [PriceVerification] = []
    @Published private(set) var barCheckins: [BarCheckin] = []
    @Published private(set) var defaultCurrency: Currency = Currency.defaultCurrency

    // MARK: - Attribute Reports
    @Published private(set) var attributeReports: [BarAttributeReport] = []
    private var attributeConsensusCache: [String: [AttributeConsensus]] = [:]

    private var latestVerificationByPriceID: [UUID: Date] = [:]
    private var verificationCountByPriceID: [UUID: Int] = [:]

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

    /// Updates the user's default currency, refreshes exchange rates and
    /// republishes so every screen recomputes prices in the new currency.
    func setDefaultCurrency(_ currency: Currency) {
        Currency.defaultCurrency = currency
        defaultCurrency = currency
        recomputePriceLevels()

        Task {
            await ExchangeRateService.shared.fetchRates()
            recomputePriceLevels()
        }
    }

    init() {
        loadFavoritesFromDisk()
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
        // Fetch each table independently so a single failure (e.g. an
        // admin-only table for a non-admin user) never blanks the whole
        // app. Public data still loads even when signed out.
        async let fetchedBars = SupabaseClient.shared.fetchBars()
        async let fetchedPrices = SupabaseClient.shared.fetchAllPrices()
        async let fetchedRatings = SupabaseClient.shared.fetchBarRatings()
        async let fetchedDrinkRatings = SupabaseClient.shared.fetchAllDrinkRatings()
        async let fetchedBrands = SupabaseClient.shared.fetchBrands()
        async let fetchedBrandRequests = SupabaseClient.shared.fetchBrandRequests()
        async let fetchedReports = SupabaseClient.shared.fetchContentReports()
        async let fetchedVerifications = SupabaseClient.shared.fetchPriceVerifications()
        async let fetchedCheckins = SupabaseClient.shared.fetchBarCheckins()
        async let fetchedAttributeReports = SupabaseClient.shared.fetchAllAttributeReports()

        if let bars = try? await fetchedBars {
            self.bars = bars
        }
        if let prices = try? await fetchedPrices {
            self.prices = prices
        }
        if let ratings = try? await fetchedRatings {
            self.barRatings = ratings
        }
        if let drinkRatings = try? await fetchedDrinkRatings {
            self.drinkRatings = drinkRatings
        }
        if let brandRequests = try? await fetchedBrandRequests {
            self.brandRequests = brandRequests
        }
        if let reports = try? await fetchedReports {
            self.reports = reports
        }
        if let verifications = try? await fetchedVerifications {
            self.priceVerifications = verifications
            recomputeVerificationIndex()
        }
        if let checkins = try? await fetchedCheckins {
            self.barCheckins = checkins
        }
        if let attributeReports = try? await fetchedAttributeReports {
            self.attributeReports = attributeReports
        }

        // Merge the server-approved catalog with the bundled defaults,
        // so the app still has sensible brands to offer even before the
        // backend is seeded.
        if let serverBrands = try? await fetchedBrands {
            var merged: [String: DrinkBrand] = [:]
            for brand in DrinkBrand.all + serverBrands {
                let key = "\(brand.drink.rawValue)|\(brand.name.lowercased())"
                merged[key] = brand
            }
            self.brands = Array(merged.values)
        }

        recomputePriceLevels()
        self.lastFetchedAt = Date()
    }

    func refreshReports() async {
        do {
            self.reports = try await SupabaseClient.shared.fetchContentReports()
        } catch { }
    }

    func fetchPrices(for bar: Bar) async {
        do {
            let fetchedPrices = try await SupabaseClient.shared.fetchPrices(for: bar.id)

            // Merge or update local prices for this bar
            self.prices.removeAll { $0.barID == bar.id }
            self.prices.append(contentsOf: fetchedPrices)
            recomputePriceLevels()
        } catch { }
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
            checkBadgesAfterContribution(for: user)
            return bar
        } catch {
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
            checkBadgesAfterContribution(for: user)
            return true
        } catch {
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
            toastCenter?.showError(error)
        }
    }

    func updatePrice(
        _ price: Price,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        amount: Decimal,
        currency: String? = nil,
        style: String? = nil,
        serving: ServingMethod? = nil,
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
            currency: currency ?? price.currency,
            reportedAt: price.reportedAt,
            reportedBy: price.reportedBy,
            style: style,
            serving: serving
        )

        do {
            try await SupabaseClient.shared.updatePrice(updatedPrice)
            self.prices[index] = updatedPrice
            recomputePriceLevels()
        } catch {
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

    /// Dollar-sign level 1…4 for the bar, comparing each drink against the
    /// market average for that same drink and size. Nil when there's no data.
    func priceLevel(for bar: Bar) -> String? {
        guard let level = priceLevelByBarID[bar.id] else { return nil }
        return String(repeating: "$", count: level)
    }

    private func recomputePriceLevels() {

        // Market average converted price per (drink, size), so a wine
        // glass is only ever compared against other wine glasses   never
        // against a pint of beer or a bottle.
        var sumsPerKey: [String: Double] = [:]
        var countsPerKey: [String: Int] = [:]

        for bar in bars {
            for summary in getPriceSummaries(for: bar) {
                let key = "\(summary.drink.rawValue)|\(summary.size.rawValue)"
                let amount = NSDecimalNumber(decimal: summary.convertedAmount).doubleValue
                sumsPerKey[key, default: 0] += amount
                countsPerKey[key, default: 0] += 1
            }
        }

        var ratiosPerBar: [UUID: Double] = [:]

        for bar in bars {
            let summaries = getPriceSummaries(for: bar)
            guard !summaries.isEmpty else { continue }

            var totalRatio = 0.0
            var count = 0

            for summary in summaries {
                let key = "\(summary.drink.rawValue)|\(summary.size.rawValue)"
                guard let n = countsPerKey[key], n > 0,
                      let sum = sumsPerKey[key], sum > 0 else { continue }

                let marketAverage = sum / Double(n)
                let amount = NSDecimalNumber(decimal: summary.convertedAmount).doubleValue
                totalRatio += amount / marketAverage
                count += 1
            }

            guard count > 0 else { continue }
            ratiosPerBar[bar.id] = totalRatio / Double(count)
        }

        guard !ratiosPerBar.isEmpty else {
            priceLevelByBarID = [:]
            return
        }

        // Ratios are relative to the market (1.0 = average). Use generous
        // bands so a bar only gets $$$ / $$$$ when it's clearly above the
        // going rate for the same drinks.
        var levels: [UUID: Int] = [:]
        for (barID, ratio) in ratiosPerBar {
            switch ratio {
            case ..<0.75:
                levels[barID] = 1
            case ..<1.25:
                levels[barID] = 2
            case ..<1.6:
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
            checkBadgesAfterContribution(for: user)
        } catch {
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
            checkBadgesAfterContribution(for: user)
        } catch {
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
            toastCenter?.showError(error)
        }
    }

    func deleteBrandRequest(_ request: BrandRequest) async {
        do {
            try await SupabaseClient.shared.deleteBrandRequest(request)
            brandRequests.removeAll { $0.id == request.id }
        } catch {
            toastCenter?.showError(error)
        }
    }

    func deleteReport(_ report: ContentReport) async {
        do {
            try await SupabaseClient.shared.deleteContentReport(report.id)
            reports.removeAll { $0.id == report.id }
        } catch {
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

    /// Compare prices for the same drink product across all bars.
    /// Returns bars sorted by price (cheapest first).
    func compareDrink(
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        style: String?,
        serving: ServingMethod?
    ) -> [(bar: Bar, summary: PriceSummary)] {

        let filtered = prices.filter {
            $0.drink == drink &&
            $0.size == size &&
            $0.brand == brand &&
            $0.style == style &&
            $0.serving == serving
        }

        let grouped = Dictionary(grouping: filtered, by: \.barID)
        var results: [(bar: Bar, summary: PriceSummary)] = []

        for (barID, groupPrices) in grouped {
            guard let bar = getBar(id: barID),
                  let summary = makePriceSummary(reports: groupPrices, barID: barID) else {
                continue
            }
            results.append((bar: bar, summary: summary))
        }

        return results.sorted {
            NSDecimalNumber(decimal: $0.summary.convertedAmount).doubleValue <
            NSDecimalNumber(decimal: $1.summary.convertedAmount).doubleValue
        }
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

    /// Number of *unreviewed* reports needed before content is auto-hidden
    /// pending admin review.
    static let autoHideReportThreshold = 3

    /// True when a target has enough unreviewed reports that it should be
    /// hidden from the public UI pending admin review.
    func isAutoHidden(targetID: String) -> Bool {
        let unreviewed = reports.filter { $0.targetID == targetID && !$0.isReviewed }.count
        return unreviewed >= Self.autoHideReportThreshold
    }

    func isBarAutoHidden(_ bar: Bar) -> Bool {
        isAutoHidden(targetID: bar.id.uuidString)
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
        let recentReports = reports.filter { now.timeIntervalSince(effectiveFreshnessDate(for: $0)) <= 365 * 24 * 60 * 60 }
        guard !recentReports.isEmpty else { return 15 }

        let reportScore = min(Double(recentReports.count) / 8.0, 1.0)
        let recencyScore = recentReports.reduce(0.0) { total, report in
            let age = max(0, now.timeIntervalSince(effectiveFreshnessDate(for: report)))
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

    // MARK: - Price Verification

    /// The date used to measure a price's freshness: the most recent of its
    /// original report and any "still accurate" confirmations.
    private func effectiveFreshnessDate(for price: Price) -> Date {
        let verifiedAt = latestVerificationByPriceID[price.id] ?? .distantPast
        return max(price.reportedAt, verifiedAt)
    }

    /// How long a "still accurate" confirmation stays valid. After this
    /// window it no longer counts toward freshness or the verified badge.
    private static let verificationLifetime: TimeInterval = 90 * 24 * 60 * 60

    /// Verifications still within the lifetime window.
    private var activeVerifications: [PriceVerification] {
        let cutoff = Date().addingTimeInterval(-Self.verificationLifetime)
        return priceVerifications.filter { $0.createdAt >= cutoff }
    }

    private func recomputeVerificationIndex() {
        var latest: [UUID: Date] = [:]
        var counts: [UUID: Int] = [:]
        for verification in activeVerifications {
            if let existing = latest[verification.priceID] {
                if verification.createdAt > existing {
                    latest[verification.priceID] = verification.createdAt
                }
            } else {
                latest[verification.priceID] = verification.createdAt
            }
            counts[verification.priceID, default: 0] += 1
        }
        latestVerificationByPriceID = latest
        verificationCountByPriceID = counts
    }

    func verificationCount(for priceID: UUID) -> Int {
        verificationCountByPriceID[priceID] ?? 0
    }

    func hasUserVerified(priceID: UUID, userID: UUID) -> Bool {
        activeVerifications.contains { $0.priceID == priceID && $0.userID == userID }
    }

    /// Records the user's "still accurate" confirmation and refreshes the
    /// local verification state. Returns true on success.
    func verifyPrice(_ price: Price, user: User) async -> Bool {
        do {
            try await SupabaseClient.shared.verifyPrice(priceID: price.id)
        } catch {
            return false
        }

        let verification = PriceVerification(
            id: UUID(),
            priceID: price.id,
            userID: user.id,
            createdAt: Date()
        )
        if let index = priceVerifications.firstIndex(where: {
            $0.priceID == price.id && $0.userID == user.id
        }) {
            priceVerifications[index] = verification
        } else {
            priceVerifications.append(verification)
        }
        recomputeVerificationIndex()
        return true
    }

    /// Removes the user's "still accurate" confirmation. Returns true on
    /// success.
    func unverifyPrice(_ price: Price, user: User) async -> Bool {
        do {
            try await SupabaseClient.shared.unverifyPrice(priceID: price.id)
        } catch {
            return false
        }

        priceVerifications.removeAll { $0.priceID == price.id && $0.userID == user.id }
        recomputeVerificationIndex()
        return true
    }

    // MARK: - Bar Check-ins

    /// A check-in counts as "here now" for this long.
    private static let checkinLifetime: TimeInterval = 2 * 60 * 60

    private var activeCheckins: [BarCheckin] {
        let cutoff = Date().addingTimeInterval(-Self.checkinLifetime)
        return barCheckins.filter { $0.createdAt >= cutoff }
    }

    func busyCount(for barID: UUID) -> Int {
        activeCheckins.filter { $0.barID == barID }.count
    }

    func hasUserCheckedIn(barID: UUID, userID: UUID) -> Bool {
        activeCheckins.contains { $0.barID == barID && $0.userID == userID }
    }

    func checkIn(bar: Bar, user: User) async -> Bool {
        do {
            try await SupabaseClient.shared.checkIn(barID: bar.id)
        } catch {
            return false
        }

        let checkin = BarCheckin(
            id: UUID(),
            barID: bar.id,
            userID: user.id,
            createdAt: Date()
        )
        if let index = barCheckins.firstIndex(where: {
            $0.barID == bar.id && $0.userID == user.id
        }) {
            barCheckins[index] = checkin
        } else {
            barCheckins.append(checkin)
        }
        return true
    }

    func uncheckIn(bar: Bar, user: User) async -> Bool {
        do {
            try await SupabaseClient.shared.uncheckIn(barID: bar.id)
        } catch {
            return false
        }

        barCheckins.removeAll { $0.barID == bar.id && $0.userID == user.id }
        return true
    }

    // MARK: - Bar Attribute Reports

    func attributeReports(for bar: Bar) -> [BarAttributeReport] {
        attributeReports.filter { $0.barID == bar.id }
    }

    func myAttributeReport(for bar: Bar, attributeKey: String, by user: User) -> BarAttributeReport? {
        attributeReports.first {
            $0.barID == bar.id &&
            $0.attributeKey == attributeKey &&
            $0.userID == user.id
        }
    }

    func attributeConsensus(for bar: Bar, attributeKey: String) -> [AttributeConsensus] {
        let cacheKey = "\(bar.id.uuidString)|\(attributeKey)"
        if let cached = attributeConsensusCache[cacheKey] {
            return cached
        }
        // Fallback to local computation if not cached
        let reports = attributeReports(for: bar).filter { $0.attributeKey == attributeKey }
        let consensus = computeConsensus(from: reports)
        attributeConsensusCache[cacheKey] = consensus
        return consensus
    }

    func allAttributeConsensus(for bar: Bar, currentUser: User?) -> [BarAttribute] {
        let alwaysShow: [BarAttributeKey] = [.outdoorSeating, .smoking]
        let keys = BarAttributeKey.allCases
        return keys.compactMap { key in
            let reports = attributeReports(for: bar).filter { $0.attributeKey == key.rawValue }
            let consensus = computeConsensus(from: reports)
            let myReport = reports.first { $0.userID == currentUser?.id }
            let shouldShow = alwaysShow.contains(key) || !consensus.isEmpty || myReport != nil
            guard shouldShow else { return nil }
            return BarAttribute(key: key, consensus: consensus, myReport: myReport)
        }
    }

    private func computeConsensus(from reports: [BarAttributeReport]) -> [AttributeConsensus] {
        let recentReports = reports.filter {
            Date().timeIntervalSince($0.createdAt) <= 365 * 24 * 60 * 60
        }
        let grouped = Dictionary(grouping: recentReports, by: { $0.attributeValue })
        let now = Date()
        let totalDays = 365.0 * 24.0 * 60.0 * 60.0
        let totalCount = Double(recentReports.count)
        let groupCount = Double(grouped.count)

        var results: [AttributeConsensus] = []
        for (value, reportsInGroup) in grouped {
            let count = reportsInGroup.count
            let lastConfirmed = reportsInGroup.map({ $0.createdAt }).max() ?? .distantPast
            var ageSum = 0.0
            for r in reportsInGroup {
                ageSum += now.timeIntervalSince(r.createdAt)
            }
            let avgAge = ageSum / Double(count)
            let recencyScore = max(0.0, 1.0 - avgAge / totalDays)

            // Volume: more reports = more confidence (caps at 10)
            let volumeScore = min(Double(count) / 10.0, 1.0)

            // Agreement: fraction of ALL reports that chose this value
            let agreementScore = totalCount > 0 ? Double(count) / totalCount : 0.0

            // Unanimity bonus: if there's only one group, everyone agrees
            let unanimityBonus = groupCount <= 1.0 ? 0.15 : 0.0

            let raw = (volumeScore * 0.30 + recencyScore * 0.35 + agreementScore * 0.35 + unanimityBonus) * 100.0
            let confidence = Int(round(raw))

            results.append(AttributeConsensus(
                value: value,
                reportCount: count,
                confidencePct: min(confidence, 100),
                lastConfirmedAt: lastConfirmed
            ))
        }
        return results.sorted { $0.reportCount > $1.reportCount }
    }

    func submitAttributeReport(
        for bar: Bar,
        attributeKey: String,
        value: String,
        evidenceText: String? = nil,
        evidencePhotoURL: URL? = nil,
        by user: User
    ) async {
        let existing = myAttributeReport(for: bar, attributeKey: attributeKey, by: user)

        let report = BarAttributeReport(
            id: existing?.id ?? UUID(),
            barID: bar.id,
            userID: user.id,
            attributeKey: attributeKey,
            attributeValue: value,
            evidenceText: evidenceText,
            evidencePhotoURL: evidencePhotoURL,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )

        do {
            try await SupabaseClient.shared.upsertAttributeReport(report)

            // Update local cache
            if let existing, let index = attributeReports.firstIndex(where: { $0.id == existing.id }) {
                attributeReports[index] = report
            } else {
                attributeReports.append(report)
            }

            // Invalidate consensus cache
            attributeConsensusCache["\(bar.id.uuidString)|\(attributeKey)"] = nil

            checkBadgesAfterContribution(for: user)
        } catch {
            toastCenter?.showError(error)
        }
    }

    func deleteAttributeReport(_ report: BarAttributeReport, by user: User) async {
        guard report.userID == user.id else { return }

        do {
            try await SupabaseClient.shared.deleteAttributeReport(report.id)
            attributeReports.removeAll { $0.id == report.id }
        } catch {
            toastCenter?.showError(error)
        }
    }

    // MARK: - Badges

    private func checkBadgesAfterContribution(for user: User) {
        BadgeService.shared.updateStreak()

        let myPriceCount = prices.filter { $0.reportedBy == user.id }.count
        let myBarCount = bars.filter { $0.createdBy == user.id }.count
        let myDrinkRatingCount = drinkRatings.filter { $0.ratedBy == user.id }.count
        let myBarRatingCount = barRatings.filter { $0.ratedBy == user.id }.count

        // Follow count is expensive to fetch; use 0 for now (will be checked on profile view)
        let followCount = 0

        let newBadges = BadgeService.shared.checkBadges(
            priceCount: myPriceCount,
            barCount: myBarCount,
            followCount: followCount,
            drinkRatingCount: myDrinkRatingCount,
            barRatingCount: myBarRatingCount
        )

        for badge in newBadges {
            toastCenter?.show("Badge earned: \(badge.name)", kind: .success)
        }
    }
}
