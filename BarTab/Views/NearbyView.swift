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

    /// Comparison value for "cheapest"/"best deal": size-normalized price
    /// per 10 cl in the default currency, falling back to the raw
    /// converted amount when a size has no estimable volume.
    private func comparisonValue(_ summary: PriceSummary) -> Double {
        summary.normalizedAmountPer10cl
            ?? NSDecimalNumber(decimal: summary.convertedAmount).doubleValue
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

                originCard

                radiusCard

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

    // MARK: - Origin card

    private var originCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Near")
                .font(.headline)

            HStack {
                Image(systemName: originIcon)
                    .foregroundColor(.barTabPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(origin.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if case .myLocation = origin, locationService.location == nil {
                        HStack(spacing: 6) {
                            Text("Waiting for location...")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                UIApplication.shared.open(
                                    URL(string: UIApplication.openSettingsURLString)!
                                )
                            } label: {
                                Text("Open Settings")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabPrimary)
                            }
                        }
                    }
                }

                Spacer()

                Menu {
                    Button {
                        origin = .myLocation
                    } label: {
                        Label("My location", systemImage: "location.fill")
                    }

                    Button {
                        showingLocationSearch = true
                    } label: {
                        Label("Search a place...", systemImage: "magnifyingglass")
                    }
                } label: {
                    Text("Change")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabPrimary)
                }
            }
        }
        .barTabCard()
    }

    private var originIcon: String {
        if case .myLocation = origin {
            return "location.fill"
        }
        return "mappin.circle.fill"
    }

    // MARK: - Radius card

    private var radiusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Radius")
                    .font(.headline)

                Spacer()

                Text(formattedRadius)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabPrimary)
            }

            Slider(value: $radiusKM, in: Self.radiusRange)
                .tint(.barTabPrimary)
        }
        .barTabCard()
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
                ForEach(nearbyBars, id: \.bar.id) { result in
                    NavigationLink(
                        destination: BarView(bar: result.bar)
                            .environmentObject(barRepository)
                            .environmentObject(userSession)
                            .environmentObject(toastCenter)
                    ) {
                        barRow(bar: result.bar, distance: result.distance)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func barRow(bar: Bar, distance: CLLocationDistance) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wineglass.fill")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [Color.barTabPrimary, Color.barTabPrimary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bar.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabText)

                    if barRepository.isBarFlagged(bar) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if let level = barRepository.priceLevel(for: bar) {
                        Text(level)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.barTabAccent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(bar.address)
                    .font(.caption)
                    .foregroundColor(.barTabSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(Self.formattedDistance(distance))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabPrimary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.barTabSecondary)
            }
        }
        .barTabCard()
    }

    // MARK: - Price filters

    private var priceFiltersSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Search bar (always visible)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.barTabSecondary)
                    .font(.subheadline)

                TextField("Search bars...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.barTabSecondary)
                    }
                }
            }
            .padding(10)
            .background(Color.barTabCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.barTabPrimary.opacity(0.25), lineWidth: 1)
            )

            // Active filter summary (always visible)
            if selectedDrinks.count > 1 || selectedBrand != nil || !selectedAmbience.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if selectedDrinks.count > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.caption2)
                                Text("\(selectedDrinks.count) drinks")
                            }
                            .font(.caption)
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
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.barTabPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        ForEach(Array(selectedAmbience)) { ambience in
                            HStack(spacing: 3) {
                                Image(systemName: ambience.icon)
                                    .font(.caption2)
                                Text(ambience.displayName)
                                Image(systemName: "xmark.circle.fill")
                                    .onTapGesture { selectedAmbience.remove(ambience) }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.barTabPrimary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Collapsible filters
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring()) {
                        filtersExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Filters")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(filtersExpanded ? 90 : 0))
                    }
                    .padding(12)
                    .background(Color.barTabPillFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .foregroundColor(.barTabText)

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
                                                    .font(.caption2)
                                                Text(drink.displayName)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedDrinks.contains(drink) ? .white : .barTabPrimary)
                                            .background(selectedDrinks.contains(drink) ? Color.barTabPrimary : Color.barTabPillFill)
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
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .foregroundColor(selectedSizes.contains(size) ? .white : .barTabPrimary)
                                                .background(selectedSizes.contains(size) ? Color.barTabPrimary : Color.barTabPillFill)
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
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedBrand == nil ? .white : .barTabPrimary)
                                            .background(selectedBrand == nil ? Color.barTabPrimary : Color.barTabPillFill)
                                            .clipShape(Capsule())
                                    }

                                    ForEach(availableBrands, id: \.self) { brand in
                                        Button {
                                            selectedBrand = brand
                                        } label: {
                                            Text(brand)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .foregroundColor(selectedBrand == brand ? .white : .barTabPrimary)
                                                .background(selectedBrand == brand ? Color.barTabPrimary : Color.barTabPillFill)
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
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedAmbience.isEmpty ? .white : .barTabPrimary)
                                            .background(selectedAmbience.isEmpty ? Color.barTabPrimary : Color.barTabPillFill)
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
                                                    .font(.caption2)
                                                Text(style.displayName)
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .foregroundColor(selectedAmbience.contains(style) ? .white : .barTabPrimary)
                                            .background(selectedAmbience.contains(style) ? Color.barTabPrimary : Color.barTabPillFill)
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
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.barTabText)

            // Sort (collapsible)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring()) {
                        sortExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Sort by")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(sortExpanded ? 90 : 0))
                    }
                    .padding(12)
                    .background(Color.barTabPillFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .foregroundColor(.barTabText)

                if sortExpanded {
                    HStack(spacing: 8) {
                        sortButton(title: "Cheapest", option: .cheapest)
                        sortButton(title: "Closest", option: .closest)
                        sortButton(title: "Brand", option: .brand)
                    }
                    .padding(.top, 8)
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.barTabText)
        }
    }

    private func filterRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
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
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(isActive ? .white : .barTabPrimary)
            .background(isActive ? Color.barTabPrimary : Color.barTabPillFill)
            .clipShape(Capsule())
        }
    }

    // MARK: - Price results

    private var priceResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private func priceRow(bar: Bar, summary: PriceSummary, isBestDeal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(bar.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if barRepository.isBarFlagged(bar) {
                            Image(systemName: "flag.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }

                        if isBestDeal {
                            Text("Best deal")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.barTabAccent)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 4) {
                        Text(summary.drink.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(summary.size.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let brand = summary.brand {
                            Text("\u{00B7}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(brand)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let style = summary.style {
                            Text("\u{00B7}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(style)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let location = locationService.location {
                        Text(DistanceService.formattedDistance(from: location, to: bar))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(summary.formattedConvertedAmount) \(Currency.defaultCurrency.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.barTabPrimary)

                    if let normalized = summary.formattedNormalizedAmountPer10cl {
                        Text("≈ \(Currency.defaultCurrency.symbol)\(normalized) / 10 cl")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(summary.reportCount == 1 ? "1 report" : "\(summary.reportCount) reports")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            confidenceView(summary: summary)
        }
        .barTabCard()
    }

    private func sortButton(title: LocalizedStringKey, option: SortOption) -> some View {
        Button {
            sortOption = option
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option == .cheapest ? "arrow.down" : "location")
                    .font(.caption)
                Text(title)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(sortOption == option ? .white : .barTabPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(sortOption == option ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func confidenceView(summary: PriceSummary) -> some View {
        let confidence = summary.confidence

        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("\u{00B7} \(summary.reportCount) \(summary.reportCount == 1 ? "report" : "reports")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(summary.confidenceLabel)
                    .font(.caption2)
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
                .font(.system(size: 32))
                .foregroundColor(.barTabPrimary.opacity(0.6))

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.barTabText)

            Text(message)
                .font(.caption)
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
                                .foregroundColor(.secondary)
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
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(result.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
