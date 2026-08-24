import SwiftUI
import MapKit
import CoreLocation

struct NearbyBarsView: View {

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
                return nil // resolved from locationService
            case .custom(_, let coordinate):
                return coordinate
            }
        }
    }

    @State private var origin: Origin = .myLocation
    @State private var radiusKM: Double = 2
    @State private var showingLocationSearch = false

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

    private var results: [(bar: Bar, distance: CLLocationDistance)] {
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

    private var formattedRadius: String {
        radiusKM < 1
            ? "\(Int(radiusKM * 1000)) m"
            : String(format: "%.1f km", radiusKM)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    BarTabScreenHeader(
                        title: "Nearby bars",
                        subtitle: "Find bars close to you or any other place."
                    )

                    originCard

                    radiusCard

                    resultsSection
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(
                Color.barTabBackground.ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .onAppear {
                locationService.requestPermission()
            }
            .sheet(isPresented: $showingLocationSearch) {
                LocationSearchSheet { name, coordinate in
                    origin = .custom(name: name, coordinate: coordinate)
                }
            }
        }
    }

    // MARK: - Origin

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
                        Text("Waiting for location…")
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
                        Label("Search a place…", systemImage: "magnifyingglass")
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

    // MARK: - Radius

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

            Slider(
                value: $radiusKM,
                in: Self.radiusRange
            )
            .tint(.barTabPrimary)
        }
        .barTabCard()
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Text("\(results.count)")
                    .foregroundColor(.secondary)
            }

            if originCoordinate == nil {
                emptyState(
                    icon: "location.slash",
                    title: "No location yet",
                    message: "Allow location access, or search for a place to look near."
                )
            } else if results.isEmpty {
                emptyState(
                    icon: "mappin.slash",
                    title: "No bars nearby",
                    message: "Try widening the radius or picking a different place."
                )
            } else {
                ForEach(results, id: \.bar.id) { result in
                    NavigationLink(
                        destination: BarView(bar: result.bar)
                            .environmentObject(barRepository)
                            .environmentObject(userSession)
                    ) {
                        resultRow(bar: result.bar, distance: result.distance)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resultRow(bar: Bar, distance: CLLocationDistance) -> some View {
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

/// Lightweight place search used to pick an arbitrary center point
/// for a radius search (as opposed to the user's current location).
private struct LocationSearchSheet: View {

    let onSelect: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.presentationMode) private var presentationMode
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
                        presentationMode.wrappedValue.dismiss()
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
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct NearbyBarsView_Previews: PreviewProvider {
    static var previews: some View {
        NearbyBarsView()
            .environmentObject(BarRepository())
            .environmentObject(UserSession())
    }
}
