import SwiftUI
import MapKit
import CoreLocation

struct NearbyView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @EnvironmentObject private var locationService: LocationService

    private enum Origin {
        case myLocation
        case custom(name: String, coordinate: CLLocationCoordinate2D)

        var label: String {
            switch self {
            case .myLocation:
                return String(localized: "My location")
            case .custom(let name, _):
                return name
            }
        }

        var coordinate: CLLocationCoordinate2D? {
            switch self {
            case .myLocation:
                return nil
            case .custom(_, let coordinate):
                return coordinate
            }
        }
    }

    private enum DisplayMode: String, CaseIterable {
        case bars = "Bars"
        case prices = "Drinks"
    }

    @State private var origin: Origin = .myLocation
    @State private var radiusKM: Double = 2
    @State private var showingLocationSearch = false
    @State private var showingLocationSheet = false
    @State private var displayMode: DisplayMode = .bars

    // Drink search state
    @State private var searchText = ""
    @State private var barSearchText = ""
    @State private var selectedDrinks: Set<Drink> = [.beer]
    @State private var selectedSizes: Set<DrinkSize> = [.fiveDeciliters]
    @State private var hasSeededDrinks = false
    @State private var selectedBrand: String?
    @State private var selectedAmbience: Set<AmbienceStyle> = []
    @State private var outdoorOnly = false

    // Collapsible filter state
    @State private var filtersExpanded = false
    @State private var sortExpanded = false
    @State private var showForYou = false

    private enum BarSortOption {
        case closest, name, busiest
    }
    @State private var barSortOption: BarSortOption = .closest

    enum SortOption {
        case cheapest
        case closest
        case brand
        case bestValue
    }

    @State private var sortOption: SortOption = .cheapest

    private static let radiusRange: ClosedRange<Double> = 0.25...25

    /// Curated cities for quick exploration without location permission.
    private static let exploreCities: [(name: String, coordinate: CLLocationCoordinate2D)] = [
        ("Zürich", CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)),
        ("Berlin", CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)),
        ("Vienna", CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)),
        ("London", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
        ("Paris", CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
        ("Amsterdam", CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041))
    ]

    private var originCoordinate: CLLocationCoordinate2D? {
        switch origin {
        case .myLocation:
            return locationService.location?.coordinate
        case .custom(_, let coordinate):
            return coordinate
        }
    }

    private var radiusMeters: CLLocationDistance {
        radiusKM * 1000
    }

    private var formattedRadius: String {
        radiusKM < 1
            ? "\(Int(radiusKM * 1000)) m"
            : String(format: "%.1f km", radiusKM)
    }

    // MARK: - Nearby bars results

    private var nearbyBars: [(bar: Bar, distance: CLLocationDistance)] {
        guard let coordinate = originCoordinate else {
            return []
        }

        let originLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        return barRepository
            .nearbyBars(coordinate: coordinate, radius: radiusMeters)
            .filter { bar in
                !outdoorOnly || bar.outdoorSeating
            }
            .filter { bar in
                !barRepository.isBarAutoHidden(bar)
            }
            .map { bar in
                (bar: bar, distance: DistanceService.distance(from: originLocation, to: bar))
            }
            .sorted { $0.distance < $1.distance }
    }

    private var filteredNearbyBars: [(bar: Bar, distance: CLLocationDistance)] {
        let trimmed = barSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var results = nearbyBars
        if !trimmed.isEmpty {
            results = results.filter {
                $0.bar.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.bar.address.localizedCaseInsensitiveContains(trimmed)
            }
        }
        switch barSortOption {
        case .closest:
            return results.sorted { $0.distance < $1.distance }
        case .name:
            return results.sorted { $0.bar.name.localizedCaseInsensitiveCompare($1.bar.name) == .orderedAscending }
        case .busiest:
            return results.sorted { barRepository.busyCount(for: $0.bar.id) > barRepository.busyCount(for: $1.bar.id) }
        }
    }

    // MARK: - Price search results

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableSizes: [DrinkSize] {
        var sizes = Set<DrinkSize>()
        for drink in selectedDrinks {
            switch drink {
            case .beer:
                sizes.formUnion([.twentyCentiliters, .twentyFiveCentiliters, .thirtyThreeCentiliters, .fiveDeciliters, .bottle])
            case .wine:
                sizes.formUnion([.oneDeciliter, .twoDeciliters, .threeDeciliters, .bottle, .glass])
            case .cocktail:
                sizes.insert(.glass)
            case .shot:
                sizes.insert(.shot)
            case .softDrink:
                sizes.formUnion([.twentyCentiliters, .twentyFiveCentiliters, .thirtyThreeCentiliters, .fiftyCentiliters, .bottle])
            case .coffee:
                sizes.formUnion([.oneDeciliter, .twoDeciliters, .threeDeciliters, .glass])
            case .other:
                sizes.formUnion(DrinkSize.allCases)
            }
        }
        return DrinkSize.allCases.filter { sizes.contains($0) }
    }

    private var availableBrands: [String] {
        var brandSet = Set<String>()
        for drink in selectedDrinks {
            for brand in barRepository.brands(for: drink) {
                brandSet.insert(brand.name)
            }
        }
        return brandSet.sorted()
    }

    private var priceResults: [(bar: Bar, summary: PriceSummary)] {
        var results: [(bar: Bar, summary: PriceSummary)] = []

        let barsInRadius: [Bar]
        if let coordinate = originCoordinate {
            barsInRadius = barRepository.nearbyBars(coordinate: coordinate, radius: radiusMeters)
        } else {
            barsInRadius = barRepository.getBars()
        }

        for bar in barsInRadius {
            if outdoorOnly && !bar.outdoorSeating { continue }
            if barRepository.isBarAutoHidden(bar) { continue }
            let summaries = barRepository.getPriceSummaries(for: bar)
            for summary in summaries {
                guard selectedDrinks.contains(summary.drink) else { continue }
                guard selectedSizes.contains(summary.size) else { continue }
                results.append((bar: bar, summary: summary))
            }
        }

        if !trimmedSearchText.isEmpty {
            results = results.filter {
                $0.bar.name.localizedCaseInsensitiveContains(trimmedSearchText)
                    || $0.bar.address.localizedCaseInsensitiveContains(trimmedSearchText)
                    || $0.summary.drink.displayName.localizedCaseInsensitiveContains(trimmedSearchText)
                    || ($0.summary.brand?.localizedCaseInsensitiveContains(trimmedSearchText) ?? false)
                    || $0.summary.size.displayName.localizedCaseInsensitiveContains(trimmedSearchText)
                    || ($0.summary.style?.localizedCaseInsensitiveContains(trimmedSearchText) ?? false)
            }
        }

        if let brand = selectedBrand, !brand.isEmpty {
            results = results.filter {
                $0.summary.brand?.localizedCaseInsensitiveCompare(brand) == .orderedSame
            }
        }

        if !selectedAmbience.isEmpty {
            results = results.filter { result in
                let barStyles = barRepository.ambienceStyles(for: result.bar)
                return !Set(barStyles).isDisjoint(with: selectedAmbience)
            }
        }

        if sortOption == .brand {
            return results.sorted { ($0.summary.brand ?? "") < ($1.summary.brand ?? "") }
        }

        guard let userLocation = locationService.location else {
            return results.sorted { comparisonValue($0.summary) < comparisonValue($1.summary) }
        }

        switch sortOption {
        case .cheapest:
            return results.sorted { comparisonValue($0.summary) < comparisonValue($1.summary) }
        case .bestValue:
            return results.sorted { (bestValue($0.summary) ?? .greatestFiniteMagnitude) < (bestValue($1.summary) ?? .greatestFiniteMagnitude) }
        case .brand:
            return results
        case .closest:
            return results.sorted {
                DistanceService.distance(from: userLocation, to: $0.bar)
                    < DistanceService.distance(from: userLocation, to: $1.bar)
            }
        }
    }

    private var bestDealSummaryID: UUID? {
        priceResults.min { comparisonValue($0.summary) < comparisonValue($1.summary) }?.summary.id
    }

    /// Bars to consider for deals/heroes: nearby when a location is known,
    /// otherwise every bar (mirrors how the Drinks results fall back).
    private var consideredBars: [Bar] {
        let bars: [Bar]
        if let coordinate = originCoordinate {
            bars = barRepository.nearbyBars(coordinate: coordinate, radius: radiusMeters)
        } else {
            bars = barRepository.getBars()
        }
        return bars
            .filter { !outdoorOnly || $0.outdoorSeating }
            .filter { !barRepository.isBarAutoHidden($0) }
    }

    /// Cheapest drink anywhere in range (ignoring drink filters), surfaced
    /// as the "best deal" hero at the top of Discover.
    private var bestDeal: (bar: Bar, summary: PriceSummary)? {
        var best: (bar: Bar, summary: PriceSummary)?
        for bar in consideredBars {
            for summary in barRepository.getPriceSummaries(for: bar) {
                if best == nil || summary.convertedAmount < best!.summary.convertedAmount {
                    best = (bar, summary)
                }
            }
        }
        return best
    }

    /// Drink deals near you that match the interests picked in onboarding,
    /// cheapest first — the basis of the "For you" carousel.
    private var forYouResults: [(bar: Bar, summary: PriceSummary)] {
        let interests = userSession.drinkInterests
        guard !interests.isEmpty else { return [] }

        var results: [(bar: Bar, summary: PriceSummary)] = []
        for bar in consideredBars {
            for summary in barRepository.getPriceSummaries(for: bar)
            where interests.contains(summary.drink) {
                results.append((bar, summary))
            }
        }
        return results
            .sorted { comparisonValue($0.summary) < comparisonValue($1.summary) }
            .prefix(8)
            .map { $0 }
    }

    /// Comparison value for "cheapest"/"best deal": the raw price in the
    /// default currency, so results reflect what you'd actually pay.
    private func comparisonValue(_ summary: PriceSummary) -> Double {
        NSDecimalNumber(decimal: summary.convertedAmount).doubleValue
    }

    /// Price per decilitre for "best value" sorting. Returns nil for
    /// non-volume servings so they sort last.
    private func bestValue(_ summary: PriceSummary) -> Double? {
        summary.pricePerDeciliter
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: BartapSpacing.md) {

                BartapScreenHeader(
                    title: String(localized: "Discover"),
                    subtitle: String(localized: "Find bars and compare drink prices nearby.")
                )

                BartapInfoBar(
                    icon: originIcon,
                    title: String(localized: "Searching near"),
                    value: origin.label,
                    trailingValue: formattedRadius
                ) {
                    showingLocationSheet = true
                }

                if let deal = bestDeal {
                    bestDealCard(deal)
                }

                if !forYouResults.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showForYou.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showForYou ? "sparkles" : "sparkles")
                            Text(showForYou ? String(localized: "Hide For you") : String(localized: "Show For you"))
                                .font(.BartapSmall)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.BartapPrimary)
                        .padding(.horizontal, BartapSpacing.sm)
                        .padding(.vertical, 6)
                        .background(Color.BartapPrimary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if showForYou {
                        forYouSection
                    }
                }

                    // Segment control
                    Picker(String(localized: "Display mode"), selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    if displayMode == .bars {
                        barsSection
                    } else {
                        priceFiltersSection
                        priceResultsSection
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selectedDrinks)
                .animation(.easeInOut(duration: 0.25), value: displayMode)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                await refreshBars()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                locationService.requestPermission()
                seedDrinksFromInterests(userSession.drinkInterests)
            }
            .onChange(of: userSession.drinkInterests) { interests in
                seedDrinksFromInterests(interests)
            }
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet { name, coordinate in
                    origin = .custom(name: name, coordinate: coordinate)
                }
            }
            .sheet(isPresented: $showingLocationSheet) {
                locationSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedDrinks) { _ in
                let validSizes = Set(availableSizes)
                selectedSizes = selectedSizes.filter { validSizes.contains($0) }
                if selectedSizes.isEmpty, let firstSize = availableSizes.first {
                    selectedSizes.insert(firstSize)
                }
                selectedBrand = nil
            }
        }
    }

    // MARK: - Location sheet
    //
    // Replaces what used to be three separate stacked cards (origin,
    // explore-a-city, radius) with one sheet opened from the compact
    // info bar — keeps the scroll content focused on results.

    private var locationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        Text(String(localized: "Location"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        HStack(spacing: BartapSpacing.sm) {
                            locationOptionButton(
                                icon: "location.fill",
                                label: String(localized: "My location"),
                                isSelected: { if case .myLocation = origin { return true }; return false }()
                            ) {
                                origin = .myLocation
                            }

                            locationOptionButton(
                                icon: "magnifyingglass",
                                label: String(localized: "Search a place"),
                                isSelected: false
                            ) {
                                showingLocationSheet = false
                                showingLocationSearch = true
                            }
                        }

                        if case .myLocation = origin, locationService.location == nil {
                            HStack(spacing: 6) {
                                Text(String(localized: "Waiting for location..."))
                                    .font(.BartapSmall)
                                    .foregroundColor(.BartapSecondary)

                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text(String(localized: "Open Settings"))
                                        .font(.BartapSmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.BartapPrimary)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        Text(String(localized: "Explore a city"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.exploreCities, id: \.name) { city in
                                    Button {
                                        origin = .custom(name: city.name, coordinate: city.coordinate)
                                    } label: {
                                        Text(city.name)
                                            .font(.BartapBodySemibold)
                                            .padding(.horizontal, BartapSpacing.sm)
                                            .padding(.vertical, 8)
                                            .foregroundColor(isCitySelected(city.name) ? .white : .BartapPrimary)
                                            .background(isCitySelected(city.name) ? Color.BartapPrimary : Color.BartapSurface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        HStack {
                            Text(String(localized: "Radius"))
                                .font(.BartapCaption)
                                .foregroundColor(.BartapSecondary)
                            Spacer()
                            Text(formattedRadius)
                                .font(.BartapBodySemibold)
                                .foregroundColor(.BartapPrimary)
                        }

                        Slider(value: $radiusKM, in: Self.radiusRange)
                            .tint(.BartapPrimary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(BartapSpacing.lg)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Search area"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { showingLocationSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func locationOptionButton(
        icon: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.BartapHeading)
                Text(label)
                    .font(.BartapCaption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BartapSpacing.sm)
            .foregroundColor(isSelected ? .white : .BartapPrimary)
            .background(isSelected ? Color.BartapPrimary : Color.BartapSurface)
            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
        }
    }

    private var originIcon: String {
        if case .myLocation = origin {
            return "location.fill"
        }
        return "mappin.circle.fill"
    }

    private func isCitySelected(_ name: String) -> Bool {
        if case .custom(let selected, _) = origin {
            return selected == name
        }
        return false
    }

    // MARK: - Bars section

    private var barsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BartapSectionHeader(title: String(localized: "Bars"), count: filteredNearbyBars.count)

            BartapSearchField(text: $barSearchText, placeholder: String(localized: "Search bars..."))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    barSortButton(title: "Closest", option: .closest)
                    barSortButton(title: "Name", option: .name)
                    barSortButton(title: "Busiest", option: .busiest)
                }
            }

            if originCoordinate == nil {
                emptyState(
                    icon: "location.slash",
                    title: "No location yet",
                    message: "Allow location access, or search for a place to look near."
                )
            } else if barRepository.bars.isEmpty {
                VStack(spacing: BartapSpacing.sm) {
                    ProgressView()
                    Text(String(localized: "Loading bars…"))
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .BartapCard()
            } else if filteredNearbyBars.isEmpty {
                emptyState(
                    icon: "mappin.slash",
                    title: "No bars nearby",
                    message: "Try widening the radius or picking a different place."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredNearbyBars.enumerated()), id: \.element.bar.id) { index, result in
                        NavigationLink(
                            destination: BarView(bar: result.bar)
                                .environmentObject(barRepository)
                                .environmentObject(userSession)
                                .environmentObject(toastCenter)
                        ) {
                            barRow(bar: result.bar, distance: result.distance)
                        }
                        .buttonStyle(.plain)

                        if index < filteredNearbyBars.count - 1 {
                            Divider().padding(.leading, BartapSpacing.md)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                        .fill(Color.BartapCardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                        .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                )
            }
        }
    }

    private func barRow(bar: Bar, distance: CLLocationDistance) -> some View {
        HStack(spacing: BartapSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.BartapPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "wineglass.fill")
                    .font(.BartapCaption)
                    .foregroundColor(.BartapPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bar.name)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.BartapText)
                        .lineLimit(1)

                    if barRepository.isBarFlagged(bar) {
                        Image(systemName: "flag.fill")
                            .font(.BartapTiny)
                            .foregroundColor(.BartapWarning)
                    }

                    if let level = barRepository.priceLevel(for: bar) {
                        Text(level)
                            .font(.BartapTiny)
                            .fontWeight(.semibold)
                            .foregroundColor(.BartapAccent)
                    }

                    if servesFavoriteDrinks(bar) {
                        Image(systemName: "heart.fill")
                            .font(.BartapTiny)
                            .foregroundColor(.BartapDanger)
                            .accessibilityLabel(Text(String(localized: "Serves your favorite drinks")))
                    }
                }

                Text(bar.address)
                    .font(.BartapSmall)
                    .foregroundColor(.BartapSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(Self.formattedDistance(distance))
                    .font(.BartapCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.BartapPrimary)

                if barRepository.busyCount(for: bar.id) > 0 {
                    Text(String(localized: "\(barRepository.busyCount(for: bar.id)) here"))
                        .font(.BartapTiny)
                        .foregroundColor(.BartapAccent)
                }

                Image(systemName: "chevron.right")
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)
            }
        }
        .padding(.horizontal, BartapSpacing.md)
        .padding(.vertical, BartapSpacing.xs)
        .contentShape(Rectangle())
    }

    /// Whether the bar has a price for any of the drinks the user picked
    /// during onboarding (shown as a heart on the row).
    private func servesFavoriteDrinks(_ bar: Bar) -> Bool {
        let interests = userSession.drinkInterests
        guard !interests.isEmpty else { return false }
        return barRepository.getPrices(for: bar).contains {
            interests.contains($0.drink)
        }
    }

    /// Seeds the "Drinks" filter from the interests chosen during onboarding,
    /// so Discover defaults to the drinks the user actually drinks.
    private func seedDrinksFromInterests(_ interests: Set<Drink>) {
        guard !hasSeededDrinks else { return }
        let valid = interests.filter { $0 != .other }
        guard !valid.isEmpty else { return }
        selectedDrinks = valid
        hasSeededDrinks = true
    }

    /// Whether a price summary matches the user's drink interests.
    private func isForYou(_ summary: PriceSummary) -> Bool {
        userSession.drinkInterests.contains(summary.drink)
    }

    // MARK: - Best deal hero

    private func bestDealCard(_ deal: (bar: Bar, summary: PriceSummary)) -> some View {
        NavigationLink(
            destination: BarView(bar: deal.bar)
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        ) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.BartapHeading)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Best deal near you"))
                        .font(.BartapTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.85))

                    Text(deal.bar.name)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("\(deal.summary.drink.displayName) \u{00B7} \(deal.summary.size.displayName)")
                        .font(.BartapSmall)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Currency.defaultCurrency.symbol) \(deal.summary.convertedAmount.formattedAmount)")
                        .font(.BartapStat)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Image(systemName: "chevron.right")
                        .font(.BartapTiny)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(BartapSpacing.md)
            .background(
                LinearGradient(
                    colors: [Color.BartapPrimary, Color.BartapPrimary.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
            .shadow(color: Color.BartapPrimary.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - For you

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.BartapHeading)
                    .foregroundColor(.BartapPrimary)

                Text(String(localized: "For you"))
                    .font(.BartapHeading)
                    .foregroundColor(.BartapText)

                Spacer()
            }

            VStack(spacing: BartapSpacing.sm) {
                ForEach(forYouResults, id: \.summary.id) { result in
                    forYouCard(result)
                }
            }
        }
    }

    private func forYouCard(_ result: (bar: Bar, summary: PriceSummary)) -> some View {
        NavigationLink(
            destination: BarView(bar: result.bar)
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: result.summary.drink.icon)
                        .font(.BartapSmall)
                        .foregroundColor(.BartapPrimary)

                    Text(result.summary.drink.displayName)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.BartapText)

                    Text("\u{00B7}")
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)

                    Text(result.summary.size.displayName)
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)
                }
                .lineLimit(1)

                Text(result.bar.name)
                    .font(.BartapSmall)
                    .foregroundColor(.BartapSecondary)
                    .lineLimit(1)

                Text("\(Currency.defaultCurrency.symbol) \(result.summary.convertedAmount.formattedAmount)")
                    .font(.BartapStat)
                    .foregroundColor(.BartapPrimary)
            }
            .padding(BartapSpacing.md)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                    .fill(Color.BartapCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                    .stroke(Color.BartapCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Price filters

    private var priceFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Search bar (always visible)
            BartapSearchField(text: $searchText, placeholder: String(localized: "Search bars or drinks..."))
            // Active filter summary (always visible)
            if selectedDrinks.count > 1 || selectedBrand != nil || !selectedAmbience.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if selectedDrinks.count > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.BartapTiny)
                                Text(String(localized: "\(selectedDrinks.count) drinks"))
                            }
                            .font(.BartapSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.BartapPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        if let brand = selectedBrand {
                            HStack(spacing: 3) {
                                Text(brand)
                                Image(systemName: "xmark.circle.fill")
                                    .onTapGesture { selectedBrand = nil }
                            }
                            .font(.BartapSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.BartapPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        ForEach(Array(selectedAmbience)) { ambience in
                            HStack(spacing: 3) {
                                Image(systemName: ambience.icon)
                                    .font(.BartapTiny)
                                Text(ambience.displayName)
                                Image(systemName: "xmark.circle.fill")
                                    .onTapGesture { selectedAmbience.remove(ambience) }
                            }
                            .font(.BartapSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.BartapPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Filters / Sort toggles share one row instead of two
            // full-width stacked strips.
            HStack(spacing: 8) {
                toggleChip(
                    title: String(localized: "Filters"),
                    isExpanded: filtersExpanded
                ) {
                    withAnimation(.spring()) { filtersExpanded.toggle() }
                }

                toggleChip(
                    title: String(localized: "Sort: \(sortLabel)"),
                    isExpanded: sortExpanded
                ) {
                    withAnimation(.spring()) { sortExpanded.toggle() }
                }
            }

            // Collapsible filters
            VStack(alignment: .leading, spacing: 8) {
                if filtersExpanded {
                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        filterRow(label: String(localized: "Drink")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(Drink.allCases, id: \.self) { drink in
                                        Button {
                                            if selectedDrinks.contains(drink) {
                                                if selectedDrinks.count > 1 {
                                                    selectedDrinks.remove(drink)
                                                }
                                            } else {
                                                selectedDrinks.insert(drink)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: drink.icon)
                                                    .font(.BartapTiny)
                                                Text(drink.displayName)
                                                    .font(.BartapSmall)
                                            }
                                            .padding(.horizontal, BartapSpacing.sm)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedDrinks.contains(drink) ? .white : .BartapPrimary)
                                            .background(selectedDrinks.contains(drink) ? Color.BartapPrimary : Color.BartapSurface)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: String(localized: "Size")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(availableSizes, id: \.self) { size in
                                        Button {
                                            if selectedSizes.contains(size) {
                                                if selectedSizes.count > 1 {
                                                    selectedSizes.remove(size)
                                                }
                                            } else {
                                                selectedSizes.insert(size)
                                            }
                                        } label: {
                                            Text(size.displayName)
                                                .font(.BartapSmall)
                                                .padding(.horizontal, BartapSpacing.sm)
                                                .padding(.vertical, 6)
                                                .foregroundColor(selectedSizes.contains(size) ? .white : .BartapPrimary)
                                                .background(selectedSizes.contains(size) ? Color.BartapPrimary : Color.BartapSurface)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: String(localized: "Brand")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Button {
                                        selectedBrand = nil
                                    } label: {
                                        Text(String(localized: "All"))
                                            .font(.BartapSmall)
                                            .padding(.horizontal, BartapSpacing.sm)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedBrand == nil ? .white : .BartapPrimary)
                                            .background(selectedBrand == nil ? Color.BartapPrimary : Color.BartapSurface)
                                            .clipShape(Capsule())
                                    }

                                    ForEach(availableBrands, id: \.self) { brand in
                                        Button {
                                            selectedBrand = brand
                                        } label: {
                                            Text(brand)
                                                .font(.BartapSmall)
                                                .padding(.horizontal, BartapSpacing.sm)
                                                .padding(.vertical, 6)
                                                .foregroundColor(selectedBrand == brand ? .white : .BartapPrimary)
                                                .background(selectedBrand == brand ? Color.BartapPrimary : Color.BartapSurface)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: String(localized: "Vibe")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Button {
                                        selectedAmbience = []
                                    } label: {
                                        Text(String(localized: "Any"))
                                            .font(.BartapSmall)
                                            .padding(.horizontal, BartapSpacing.sm)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedAmbience.isEmpty ? .white : .BartapPrimary)
                                            .background(selectedAmbience.isEmpty ? Color.BartapPrimary : Color.BartapSurface)
                                            .clipShape(Capsule())
                                    }

                                    ForEach(AmbienceStyle.allCases) { style in
                                        Button {
                                            if selectedAmbience.contains(style) {
                                                selectedAmbience.remove(style)
                                            } else {
                                                selectedAmbience.insert(style)
                                            }
                                        } label: {
                                            HStack(spacing: 3) {
                                                Image(systemName: style.icon)
                                                    .font(.BartapTiny)
                                                Text(style.displayName)
                                            }
                                            .font(.BartapSmall)
                                            .padding(.horizontal, BartapSpacing.sm)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedAmbience.contains(style) ? .white : .BartapPrimary)
                                            .background(selectedAmbience.contains(style) ? Color.BartapPrimary : Color.BartapSurface)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: String(localized: "Seating")) {
                            HStack(spacing: 6) {
                                filterPill(
                                    icon: "sun.max.fill",
                                    label: String(localized: "Outdoor"),
                                    isActive: outdoorOnly
                                ) {
                                    outdoorOnly.toggle()
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .font(.BartapBody)
            .fontWeight(.medium)
            .foregroundColor(.BartapText)

            if sortExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        sortButton(title: "Cheapest", option: .cheapest)
                        sortButton(title: "Best value", option: .bestValue)
                        sortButton(title: "Closest", option: .closest)
                        sortButton(title: "Brand", option: .brand)
                    }
                }
            }
        }
    }

    private func filterRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.BartapSmall)
                .fontWeight(.medium)
                .foregroundColor(.BartapSecondary)
            content()
        }
    }

    private func filterPill(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.BartapTiny)
                Text(label)
                    .font(.BartapSmall)
            }
            .padding(.horizontal, BartapSpacing.sm)
            .padding(.vertical, 6)
            .foregroundColor(isActive ? .white : .BartapPrimary)
            .background(isActive ? Color.BartapPrimary : Color.BartapSurface)
            .clipShape(Capsule())
        }
    }

    // MARK: - Price results

    private var priceResultsSection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.xs) {
            BartapSectionHeader(title: String(localized: "Drinks"), count: priceResults.count)

            if priceResults.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No drinks found",
                    message: !trimmedSearchText.isEmpty
                        ? "No drinks match \"\(trimmedSearchText)\"."
                        : "Be the first to add a drink in this area."
                )
            } else {
                VStack(spacing: BartapSpacing.xs) {
                    ForEach(priceResults, id: \.summary.id) { result in
                        NavigationLink(
                            destination: BarView(bar: result.bar)
                                .environmentObject(barRepository)
                                .environmentObject(userSession)
                                .environmentObject(toastCenter)
                        ) {
                            priceRow(
                                bar: result.bar,
                                summary: result.summary,
                                isBestDeal: result.summary.id == bestDealSummaryID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func priceRow(bar: Bar, summary: PriceSummary, isBestDeal: Bool = false) -> some View {
        HStack(alignment: .top, spacing: BartapSpacing.sm) {

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(bar.name)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.BartapText)
                        .lineLimit(1)

                    if barRepository.isBarFlagged(bar) {
                        Image(systemName: "flag.fill")
                            .font(.BartapTiny)
                            .foregroundColor(.BartapWarning)
                    }
                }

                HStack(spacing: 4) {
                    Text(summary.drink.displayName)
                    Text("\u{00B7}")
                    Text(summary.size.displayName)

                    if let brand = summary.brand {
                        Text("\u{00B7}")
                        Text(brand)
                    }

                    if let style = summary.style {
                        Text("\u{00B7}")
                        Text(style)
                    }
                }
                .font(.BartapSmall)
                .foregroundColor(.BartapSecondary)
                .lineLimit(1)

                HStack(spacing: 6) {
                    if let location = locationService.location {
                        Text(DistanceService.formattedDistance(from: location, to: bar))
                    }

                    Text(summary.reportCount == 1 ? String(localized: "1 report") : String(localized: "\(summary.reportCount) reports"))
                }
                .font(.BartapTiny)
                .foregroundColor(.BartapSecondary.opacity(0.8))

                confidenceView(summary: summary)
                    .padding(.top, 2)
            }

            Spacer(minLength: BartapSpacing.xs)

            VStack(alignment: .trailing, spacing: 4) {
                if isForYou(summary) {
                    Text(String(localized: "For you"))
                        .font(.BartapTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.BartapPrimary)
                        .clipShape(Capsule())
                }

                if isBestDeal {
                    Text(String(localized: "Best deal"))
                        .font(.BartapTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.BartapAccent)
                        .clipShape(Capsule())
                }

                Text(summary.formattedConvertedAmount)
                    .font(.BartapStat)
                    .foregroundColor(.BartapPrimary)

                Text(Currency.defaultCurrency.rawValue)
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)

                if summary.isStale {
                    Text(String(localized: "Stale"))
                        .font(.BartapTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.BartapWarning)
                        .clipShape(Capsule())
                }
            }
        }
        .BartapCard()
        .opacity(summary.isStale ? 0.72 : 1.0)
    }

    private func sortButton(title: LocalizedStringKey, option: SortOption) -> some View {
        Button {
            sortOption = option
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option == .cheapest ? "arrow.down" : "location")
                    .font(.BartapTiny)
                Text(title)
                    .lineLimit(1)
            }
            .font(.BartapSmall)
            .fontWeight(.semibold)
            .foregroundColor(sortOption == option ? .white : .BartapPrimary)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, BartapSpacing.sm)
            .padding(.vertical, 7)
            .background(sortOption == option ? Color.BartapPrimary : Color.BartapPrimary.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    private func barSortButton(title: LocalizedStringKey, option: BarSortOption) -> some View {
        Button {
            barSortOption = option
        } label: {
            Text(title)
                .font(.BartapSmall)
                .fontWeight(.semibold)
                .foregroundColor(barSortOption == option ? .white : .BartapPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, BartapSpacing.sm)
                .padding(.vertical, 7)
                .background(barSortOption == option ? Color.BartapPrimary : Color.BartapPrimary.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private var sortLabel: String {
        switch sortOption {
        case .cheapest: return "Cheapest"
        case .bestValue: return "Best value"
        case .closest: return "Closest"
        case .brand: return "Brand"
        }
    }

    /// Compact toggle used for the "Filters" / "Sort" row — replaces two
    /// full-width stacked disclosure strips with a pair of pill buttons.
    private func toggleChip(
        title: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BartapSpacing.xxs) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.BartapTiny.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(.BartapCaption)
            .fontWeight(.semibold)
            .foregroundColor(isExpanded ? .white : .BartapText)
            .padding(.horizontal, BartapSpacing.sm)
            .padding(.vertical, BartapSpacing.xs)
            .background(isExpanded ? Color.BartapPrimary : Color.BartapSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isExpanded ? Color.clear : Color.BartapCardBorder, lineWidth: 1)
            )
        }
    }

    private func confidenceView(summary: PriceSummary) -> some View {
        let confidence = summary.confidence

        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(String(localized: "Confidence"))
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)

                    Text(String(localized: "\u{00B7} \(summary.reportCount) \(summary.reportCount == 1 ? "report" : "reports")"))
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)

                Spacer()

                Text(summary.confidenceLabel)
                    .font(.BartapTiny)
                    .fontWeight(.semibold)
                    .foregroundColor(.BartapPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.BartapPrimary.opacity(0.12))

                    Capsule()
                        .fill(Color.BartapPrimary)
                        .frame(width: geometry.size.width * CGFloat(confidence) / 100)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.BartapEmptyIcon)
                .foregroundColor(.BartapPrimary.opacity(0.6))

            Text(title)
                .font(.BartapBody)
                .fontWeight(.medium)
                .foregroundColor(.BartapText)

            Text(message)
                .font(.BartapSmall)
                .foregroundColor(.BartapSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func refreshBars() async {
        await barRepository.fetchAllData()
        HapticEngine.lightTap()
    }

    private static func formattedDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance)) m"
        }
        return String(format: "%.1f km", distance / 1000)
    }
}

// MARK: - Location search sheet

private struct LocationSearchSheet: View {

    let onSelect: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: ToastCenter
    @StateObject private var searchService = PlaceSearchService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: BartapSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.BartapPrimary)

                    TextField(
                        String(localized: "Search a city or place"),
                        text: Binding(
                            get: { searchService.query },
                            set: { searchService.updateQuery($0) }
                        )
                    )
                    .textFieldStyle(.plain)

                    if !searchService.query.isEmpty {
                        Button {
                            searchService.updateQuery("")
                            searchService.clearResults()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.BartapSecondary)
                        }
                    }
                }
                .padding(14)
                .background(Color.BartapCardFill)
                .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                        .stroke(Color.BartapPrimary.opacity(0.25), lineWidth: 1)
                )
                .padding()

                List(searchService.results, id: \.self) { result in
                    Button {
                        select(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.title)
                                .font(.BartapHeading)
                                .foregroundColor(.primary)

                            Text(result.subtitle)
                                .font(.BartapBody)
                                .foregroundColor(.BartapSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Search a place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        search.start { response, error in
            guard error == nil, let item = response?.mapItems.first else {
                DispatchQueue.main.async {
                    toastCenter.show(String(localized: "Could not find location"), kind: .error)
                }
                return
            }

            DispatchQueue.main.async {
                let name = item.name ?? completion.title
                onSelect(name, item.placemark.coordinate)
                dismiss()
            }
        }
    }
}

struct NearbyView_Previews: PreviewProvider {
    static var previews: some View {
        NearbyView()
            .environmentObject(BarRepository())
            .environmentObject(UserSession())
            .environmentObject(ToastCenter())
    }
}
