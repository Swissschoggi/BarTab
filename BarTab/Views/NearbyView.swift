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
    @State private var isRefreshing = false

    // Drink search state
    @State private var searchText = ""
    @State private var selectedDrinks: Set<Drink> = [.beer]
    @State private var selectedSizes: Set<DrinkSize> = [.fiveDeciliters]
    @State private var selectedBrand: String?
    @State private var selectedAmbience: Set<AmbienceStyle> = []
    @State private var outdoorOnly = false

    // Collapsible filter state
    @State private var filtersExpanded = false
    @State private var sortExpanded = false

    enum SortOption {
        case cheapest
        case closest
        case brand
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

    /// Comparison value for "cheapest"/"best deal": the raw price in the
    /// default currency, so results reflect what you'd actually pay.
    private func comparisonValue(_ summary: PriceSummary) -> Double {
        NSDecimalNumber(decimal: summary.convertedAmount).doubleValue
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BarTabScreenHeader(
                    title: "Discover",
                    subtitle: "Find bars and compare drink prices nearby."
                )

                BarTabInfoBar(
                    icon: originIcon,
                    title: "Searching near",
                    value: origin.label,
                    trailingValue: formattedRadius
                ) {
                    showingLocationSheet = true
                }

                    // Segment control
                    Picker("Display mode", selection: $displayMode) {
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
            .background(Color.barTabBackground.ignoresSafeArea())
            .refreshable {
                await refreshBars()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                locationService.requestPermission()
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {

                    VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                        Text("Location")
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        HStack(spacing: BarTabSpacing.sm) {
                            locationOptionButton(
                                icon: "location.fill",
                                label: "My location",
                                isSelected: { if case .myLocation = origin { return true }; return false }()
                            ) {
                                origin = .myLocation
                            }

                            locationOptionButton(
                                icon: "magnifyingglass",
                                label: "Search a place",
                                isSelected: false
                            ) {
                                showingLocationSheet = false
                                showingLocationSearch = true
                            }
                        }

                        if case .myLocation = origin, locationService.location == nil {
                            HStack(spacing: 6) {
                                Text("Waiting for location...")
                                    .font(.barTabSmall)
                                    .foregroundColor(.barTabSecondary)

                                Button {
                                    UIApplication.shared.open(
                                        URL(string: UIApplication.openSettingsURLString)!
                                    )
                                } label: {
                                    Text("Open Settings")
                                        .font(.barTabSmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.barTabPrimary)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                        Text("Explore a city")
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.exploreCities, id: \.name) { city in
                                    Button {
                                        origin = .custom(name: city.name, coordinate: city.coordinate)
                                    } label: {
                                        Text(city.name)
                                            .font(.barTabBodySemibold)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .foregroundColor(isCitySelected(city.name) ? .white : .barTabPrimary)
                                            .background(isCitySelected(city.name) ? Color.barTabPrimary : Color.barTabSurface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                        HStack {
                            Text("Radius")
                                .font(.barTabCaption)
                                .foregroundColor(.barTabSecondary)
                            Spacer()
                            Text(formattedRadius)
                                .font(.barTabBodySemibold)
                                .foregroundColor(.barTabPrimary)
                        }

                        Slider(value: $radiusKM, in: Self.radiusRange)
                            .tint(.barTabPrimary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(BarTabSpacing.lg)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Search area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingLocationSheet = false }
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
                    .font(.barTabHeading)
                Text(label)
                    .font(.barTabCaption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BarTabSpacing.sm)
            .foregroundColor(isSelected ? .white : .barTabPrimary)
            .background(isSelected ? Color.barTabPrimary : Color.barTabSurface)
            .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
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
            BarTabSectionHeader(title: "Bars", count: nearbyBars.count)

            if originCoordinate == nil {
                emptyState(
                    icon: "location.slash",
                    title: "No location yet",
                    message: "Allow location access, or search for a place to look near."
                )
            } else if nearbyBars.isEmpty {
                emptyState(
                    icon: "mappin.slash",
                    title: "No bars nearby",
                    message: "Try widening the radius or picking a different place."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(nearbyBars.enumerated()), id: \.element.bar.id) { index, result in
                        NavigationLink(
                            destination: BarView(bar: result.bar)
                                .environmentObject(barRepository)
                                .environmentObject(userSession)
                                .environmentObject(toastCenter)
                        ) {
                            barRow(bar: result.bar, distance: result.distance)
                        }
                        .buttonStyle(.plain)

                        if index < nearbyBars.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                        .fill(Color.barTabCardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                        .stroke(Color.barTabCardBorder, lineWidth: 1)
                )
            }
        }
    }

    private func barRow(bar: Bar, distance: CLLocationDistance) -> some View {
        HStack(spacing: BarTabSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.barTabPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "wineglass.fill")
                    .font(.barTabCaption)
                    .foregroundColor(.barTabPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bar.name)
                        .font(.barTabBodySemibold)
                        .foregroundColor(.barTabText)
                        .lineLimit(1)

                    if barRepository.isBarFlagged(bar) {
                        Image(systemName: "flag.fill")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabWarning)
                    }

                    if let level = barRepository.priceLevel(for: bar) {
                        Text(level)
                            .font(.barTabTiny)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabAccent)
                    }
                }

                Text(bar.address)
                    .font(.barTabSmall)
                    .foregroundColor(.barTabSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(Self.formattedDistance(distance))
                    .font(.barTabCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabPrimary)

                Image(systemName: "chevron.right")
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, BarTabSpacing.md)
        .padding(.vertical, BarTabSpacing.xs)
        .contentShape(Rectangle())
    }

    // MARK: - Price filters

    private var priceFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Search bar (always visible)
            BarTabSearchField(text: $searchText, placeholder: "Search bars...")
            // Active filter summary (always visible)
            if selectedDrinks.count > 1 || selectedBrand != nil || !selectedAmbience.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if selectedDrinks.count > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.barTabTiny)
                                Text("\(selectedDrinks.count) drinks")
                            }
                            .font(.barTabSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.barTabPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        if let brand = selectedBrand {
                            HStack(spacing: 3) {
                                Text(brand)
                                Image(systemName: "xmark.circle.fill")
                                    .onTapGesture { selectedBrand = nil }
                            }
                            .font(.barTabSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.barTabPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        ForEach(Array(selectedAmbience)) { ambience in
                            HStack(spacing: 3) {
                                Image(systemName: ambience.icon)
                                    .font(.barTabTiny)
                                Text(ambience.displayName)
                                Image(systemName: "xmark.circle.fill")
                                    .onTapGesture { selectedAmbience.remove(ambience) }
                            }
                            .font(.barTabSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.barTabPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Filters / Sort toggles share one row instead of two
            // full-width stacked strips.
            HStack(spacing: 8) {
                toggleChip(
                    title: "Filters",
                    isExpanded: filtersExpanded
                ) {
                    withAnimation(.spring()) { filtersExpanded.toggle() }
                }

                toggleChip(
                    title: "Sort: \(sortLabel)",
                    isExpanded: sortExpanded
                ) {
                    withAnimation(.spring()) { sortExpanded.toggle() }
                }
            }

            // Collapsible filters
            VStack(alignment: .leading, spacing: 8) {
                if filtersExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        filterRow(label: "Drink") {
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
                                                    .font(.barTabTiny)
                                                Text(drink.displayName)
                                                    .font(.barTabSmall)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedDrinks.contains(drink) ? .white : .barTabPrimary)
                                            .background(selectedDrinks.contains(drink) ? Color.barTabPrimary : Color.barTabSurface)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: "Size") {
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
                                                .font(.barTabSmall)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .foregroundColor(selectedSizes.contains(size) ? .white : .barTabPrimary)
                                                .background(selectedSizes.contains(size) ? Color.barTabPrimary : Color.barTabSurface)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: "Brand") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Button {
                                        selectedBrand = nil
                                    } label: {
                                        Text("All")
                                            .font(.barTabSmall)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedBrand == nil ? .white : .barTabPrimary)
                                            .background(selectedBrand == nil ? Color.barTabPrimary : Color.barTabSurface)
                                            .clipShape(Capsule())
                                    }

                                    ForEach(availableBrands, id: \.self) { brand in
                                        Button {
                                            selectedBrand = brand
                                        } label: {
                                            Text(brand)
                                                .font(.barTabSmall)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .foregroundColor(selectedBrand == brand ? .white : .barTabPrimary)
                                                .background(selectedBrand == brand ? Color.barTabPrimary : Color.barTabSurface)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: "Vibe") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Button {
                                        selectedAmbience = []
                                    } label: {
                                        Text("Any")
                                            .font(.barTabSmall)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedAmbience.isEmpty ? .white : .barTabPrimary)
                                            .background(selectedAmbience.isEmpty ? Color.barTabPrimary : Color.barTabSurface)
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
                                                    .font(.barTabTiny)
                                                Text(style.displayName)
                                            }
                                            .font(.barTabSmall)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedAmbience.contains(style) ? .white : .barTabPrimary)
                                            .background(selectedAmbience.contains(style) ? Color.barTabPrimary : Color.barTabSurface)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        filterRow(label: "Seating") {
                            HStack(spacing: 6) {
                                filterPill(
                                    icon: "sun.max.fill",
                                    label: "Outdoor",
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
            .font(.barTabBody)
            .fontWeight(.medium)
            .foregroundColor(.barTabText)

            if sortExpanded {
                HStack(spacing: 8) {
                    sortButton(title: "Cheapest", option: .cheapest)
                    sortButton(title: "Closest", option: .closest)
                    sortButton(title: "Brand", option: .brand)
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
                .font(.barTabSmall)
                .fontWeight(.medium)
                .foregroundColor(.barTabSecondary)
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
                    .font(.barTabTiny)
                Text(label)
                    .font(.barTabSmall)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(isActive ? .white : .barTabPrimary)
            .background(isActive ? Color.barTabPrimary : Color.barTabSurface)
            .clipShape(Capsule())
        }
    }

    // MARK: - Price results

    private var priceResultsSection: some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
            BarTabSectionHeader(title: "Drinks", count: priceResults.count)

            if priceResults.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No drinks found",
                    message: !trimmedSearchText.isEmpty
                        ? "No bars match \"\(trimmedSearchText)\"."
                        : "Be the first to add a drink in this area."
                )
            } else {
                VStack(spacing: BarTabSpacing.xs) {
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
        HStack(alignment: .top, spacing: BarTabSpacing.sm) {

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(bar.name)
                        .font(.barTabBodySemibold)
                        .foregroundColor(.barTabText)
                        .lineLimit(1)

                    if barRepository.isBarFlagged(bar) {
                        Image(systemName: "flag.fill")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabWarning)
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
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)
                .lineLimit(1)

                HStack(spacing: 6) {
                    if let location = locationService.location {
                        Text(DistanceService.formattedDistance(from: location, to: bar))
                    }

                    Text(summary.reportCount == 1 ? "1 report" : "\(summary.reportCount) reports")
                }
                .font(.barTabTiny)
                .foregroundColor(.barTabSecondary.opacity(0.8))

                confidenceView(summary: summary)
                    .padding(.top, 2)
            }

            Spacer(minLength: BarTabSpacing.xs)

            VStack(alignment: .trailing, spacing: 4) {
                if isBestDeal {
                    Text("Best deal")
                        .font(.barTabTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.barTabAccent)
                        .clipShape(Capsule())
                }

                Text(summary.formattedConvertedAmount)
                    .font(.barTabStat)
                    .foregroundColor(.barTabPrimary)

                Text(Currency.defaultCurrency.rawValue)
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)
            }
        }
        .barTabCard()
    }

    private func sortButton(title: LocalizedStringKey, option: SortOption) -> some View {
        Button {
            sortOption = option
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option == .cheapest ? "arrow.down" : "location")
                    .font(.barTabTiny)
                Text(title)
            }
            .font(.barTabSmall)
            .fontWeight(.semibold)
            .foregroundColor(sortOption == option ? .white : .barTabPrimary)
            .padding(.horizontal, BarTabSpacing.sm)
            .padding(.vertical, 7)
            .background(sortOption == option ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    private var sortLabel: String {
        switch sortOption {
        case .cheapest: return "Cheapest"
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
            HStack(spacing: 5) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.barTabTiny.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(.barTabCaption)
            .fontWeight(.semibold)
            .foregroundColor(isExpanded ? .white : .barTabText)
            .padding(.horizontal, BarTabSpacing.sm)
            .padding(.vertical, BarTabSpacing.xs)
            .background(isExpanded ? Color.barTabPrimary : Color.barTabSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isExpanded ? Color.clear : Color.barTabCardBorder, lineWidth: 1)
            )
        }
    }

    private func confidenceView(summary: PriceSummary) -> some View {
        let confidence = summary.confidence

        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Confidence")
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)

                Text("\u{00B7} \(summary.reportCount) \(summary.reportCount == 1 ? "report" : "reports")")
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)

                Spacer()

                Text(summary.confidenceLabel)
                    .font(.barTabTiny)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.barTabPrimary.opacity(0.12))

                    Capsule()
                        .fill(Color.barTabPrimary)
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
                .font(.barTabEmptyIcon)
                .foregroundColor(.barTabPrimary.opacity(0.6))

            Text(title)
                .font(.barTabBody)
                .fontWeight(.medium)
                .foregroundColor(.barTabText)

            Text(message)
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func refreshBars() async {
        isRefreshing = true
        defer { isRefreshing = false }

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
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.barTabPrimary)

                    TextField(
                        "Search a city or place",
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
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                }
                .padding(14)
                .background(Color.barTabCardFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.barTabPrimary.opacity(0.25), lineWidth: 1)
                )
                .padding()

                List(searchService.results, id: \.self) { result in
                    Button {
                        select(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.title)
                                .font(.barTabHeading)
                                .foregroundColor(.primary)

                            Text(result.subtitle)
                                .font(.barTabBody)
                                .foregroundColor(.barTabSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Search a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
                    toastCenter.show("Could not find location", kind: .error)
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
