import SwiftUI
import MapKit
import CoreLocation

struct NearbyView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

    @StateObject private var locationService = LocationService()

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
        case prices = "Prices"
    }

    @State private var origin: Origin = .myLocation
    @State private var radiusKM: Double = 2
    @State private var showingLocationSearch = false
    @State private var displayMode: DisplayMode = .bars

    // Price search state
    @State private var searchText = ""
    @State private var selectedDrinks: Set<Drink> = [.beer]
    @State private var selectedSizes: Set<DrinkSize> = [.fiveDeciliters]
    @State private var selectedBrand: String?

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

        if sortOption == .brand {
            return results.sorted { ($0.summary.brand ?? "") < ($1.summary.brand ?? "") }
        }

        guard let userLocation = locationService.location else {
            return results.sorted { $0.summary.amount < $1.summary.amount }
        }

        switch sortOption {
        case .cheapest:
            return results.sorted { $0.summary.amount < $1.summary.amount }
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
        priceResults.min { $0.summary.amount < $1.summary.amount }?.summary.id
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    BarTabScreenHeader(
                        title: "Discover",
                        subtitle: "Find bars and compare prices nearby."
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
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationBarHidden(true)
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
                        Text("Waiting for location...")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                    ) {
                        barRow(bar: result.bar, distance: result.distance)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func barRow(bar: Bar, distance: CLLocationDistance) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "wineglass.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.barTabPrimary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(bar.name)
                        .font(.headline)

                    if barRepository.isBarFlagged(bar) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Text(bar.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(Self.formattedDistance(distance))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.barTabPrimary)
        }
        .barTabCard()
    }

    // MARK: - Price filters

    private var priceFiltersSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search by bar name", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.barTabPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("Drink")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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
                                HStack(spacing: 6) {
                                    Image(systemName: drink.icon)
                                    Text(drink.displayName)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundColor(selectedDrinks.contains(drink) ? .white : .barTabPrimary)
                                .background(selectedDrinks.contains(drink) ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Size")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .foregroundColor(selectedSizes.contains(size) ? .white : .barTabPrimary)
                                    .background(selectedSizes.contains(size) ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Brand")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            selectedBrand = nil
                        } label: {
                            Text("All")
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundColor(selectedBrand == nil ? .white : .barTabPrimary)
                                .background(selectedBrand == nil ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        ForEach(availableBrands, id: \.self) { brand in
                            Button {
                                selectedBrand = brand
                            } label: {
                                Text(brand)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .foregroundColor(selectedBrand == brand ? .white : .barTabPrimary)
                                    .background(selectedBrand == brand ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Sort by")
                    .font(.headline)

                HStack(spacing: 10) {
                    sortButton(title: "Cheapest", option: .cheapest)
                    sortButton(title: "Closest", option: .closest)
                    sortButton(title: "Brand", option: .brand)
                }
            }
        }
    }

    // MARK: - Price results

    private var priceResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BarTabSectionHeader(title: "Prices", count: priceResults.count)

            if priceResults.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No prices found",
                    message: !trimmedSearchText.isEmpty
                        ? "No bars match \"\(trimmedSearchText)\"."
                        : "Be the first to add a price in this area."
                )
            } else {
                ForEach(priceResults, id: \.summary.id) { result in
                    NavigationLink(
                        destination: BarView(bar: result.bar)
                            .environmentObject(barRepository)
                            .environmentObject(userSession)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(bar.name)
                            .font(.headline)

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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.barTabAccent)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(summary.drink.displayName) \u{00B7} \(summary.size.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let brand = summary.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let location = locationService.location {
                        Text(DistanceService.formattedDistance(from: location, to: bar))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(summary.formattedAmount) \(summary.currency)")
                        .font(.headline)
                        .foregroundColor(.barTabPrimary)

                    Text(summary.reportCount == 1 ? "1 report" : "\(summary.reportCount) reports")
                        .font(.caption)
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
            HStack(spacing: 5) {
                Image(systemName: option == .cheapest ? "arrow.down" : "location")
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(sortOption == option ? .white : .barTabPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(sortOption == option ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func confidenceView(summary: PriceSummary) -> some View {
        let confidence = summary.confidence

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Price confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\u{00B7} \(summary.reportCount) \(summary.reportCount == 1 ? "report" : "reports")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(summary.confidenceLabel)
                    .font(.caption)
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
            .frame(height: 6)
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 35))
                .foregroundColor(.barTabPrimary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
    @StateObject private var searchService = PlaceSearchService()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

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
                .background(Color.barTabBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    }
}
