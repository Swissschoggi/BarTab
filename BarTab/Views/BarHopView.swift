import SwiftUI
import CoreLocation
import MapKit
import UIKit

/// Generates a fun 3-bar walking crawl route with estimated drink savings.
struct BarHopView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRoute: [Bar] = []
    @State private var isGenerating = false
    @State private var showingRouteMap = false
    @State private var showingLocationPicker = false

    /// A user-chosen crawl origin. `nil` means "my current location".
    @State private var crawlOrigin: CLLocationCoordinate2D?
    @State private var originName: String = ""

    private var originLocation: CLLocation? {
        if let crawlOrigin {
            return CLLocation(latitude: crawlOrigin.latitude, longitude: crawlOrigin.longitude)
        }
        return locationService.location
    }

    private var originLabel: String {
        if crawlOrigin != nil {
            return originName.isEmpty ? String(localized: "Chosen place") : originName
        }
        return String(localized: "My location")
    }

    /// An `Equatable` snapshot of the chosen origin so `.onChange` can
    /// observe it (`CLLocationCoordinate2D` isn't `Equatable`).
    private var crawlOriginKey: String {
        guard let crawlOrigin else { return "my-location" }
        return "\(crawlOrigin.latitude),\(crawlOrigin.longitude)"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {
                    locationSection

                    if selectedRoute.isEmpty {
                        emptyState
                    } else {
                        routeSection
                    }
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .onAppear {
                locationService.requestPermission()
            }
            .navigationTitle(String(localized: "Bar Hop"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingRouteMap) {
            CrawlRouteView(stops: selectedRoute)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedCoordinate: $crawlOrigin,
                address: $originName
            )
            .environmentObject(locationService)
        }
        .onChange(of: crawlOriginKey) { _ in
            generateRoute()
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
            Text(String(localized: "LOCATION"))
                .font(.barTabCaption)
                .foregroundColor(.barTabSecondary)

            FlowLayout(spacing: BarTabSpacing.xs) {
                originPill(
                    title: String(localized: "My location"),
                    icon: "location.fill",
                    isSelected: crawlOrigin == nil
                ) {
                    crawlOrigin = nil
                    originName = ""
                }

                originPill(
                    title: crawlOrigin == nil ? String(localized: "Choose a place…") : originLabel,
                    icon: crawlOrigin == nil ? "mappin.and.ellipse" : "mappin.circle.fill",
                    isSelected: crawlOrigin != nil
                ) {
                    showingLocationPicker = true
                }
            }
        }
    }

    private func originPill(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.barTabCaption)
                Text(title)
                    .font(.barTabCaption)
                    .lineLimit(1)
            }
            .padding(.horizontal, BarTabSpacing.sm)
            .padding(.vertical, 8)
            .background(isSelected ? Color.barTabPrimary : Color.barTabSurface)
            .foregroundColor(isSelected ? .white : .barTabText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: BarTabSpacing.md) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.barTabEmptyIconLarge)
                .foregroundColor(.barTabPrimary.opacity(0.6))

            Text(String(localized: "Plan your crawl"))
                .font(.barTabHeading)
                .foregroundColor(.barTabText)

            Text(String(localized: "BarTab will pick three bars within walking distance and draw the route."))
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)
                .multilineTextAlignment(.center)

            Button {
                generateRoute()
            } label: {
                Text(String(localized: "Generate Route"))
                    .barTabPrimaryButton()
            }
        }
        .frame(maxWidth: .infinity)
        .barTabCard()
    }

    // MARK: - Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
            HStack {
                Text(String(localized: "YOUR CRAWL"))
                    .font(.barTabCaption)
                    .foregroundColor(.barTabSecondary)

                Spacer()

                Button {
                    generateRoute()
                } label: {
                    Label(String(localized: "Shuffle"), systemImage: "shuffle")
                        .barTabPillButton()
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(selectedRoute.enumerated()), id: \.element.id) { index, bar in
                    routeRow(index: index, bar: bar)

                    if index < selectedRoute.count - 1 {
                        Divider()
                            .foregroundColor(.barTabCardBorder)
                            .padding(.leading, 58)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                    .fill(Color.barTabCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 0.5)
            )

            Button {
                showingRouteMap = true
            } label: {
                Label(String(localized: "Show Route on Map"), systemImage: "map.fill")
                    .barTabPrimaryButton()
            }
            .padding(.top, BarTabSpacing.xs)

            Button {
                generateRoute()
            } label: {
                Text(String(localized: "Try Another Route"))
                    .barTabSecondaryButton()
            }
        }
    }

    private func routeRow(index: Int, bar: Bar) -> some View {
        HStack(spacing: BarTabSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.barTabPrimary)
                    .frame(width: 30, height: 30)
                Text("\(index + 1)")
                    .font(.barTabBodySemibold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bar.name)
                    .font(.barTabBodySemibold)
                    .foregroundColor(.barTabText)
                    .lineLimit(1)

                Text(bar.address)
                    .font(.barTabCaption)
                    .foregroundColor(.barTabSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let popular = barRepository.popularAmbience(for: bar) {
                HStack(spacing: 3) {
                    Image(systemName: popular.icon)
                        .font(.barTabTiny)
                    Text(popular.displayName)
                        .font(.barTabTiny)
                }
                .barTabPillButton()
            }
        }
        .padding(.horizontal, BarTabSpacing.md)
        .padding(.vertical, BarTabSpacing.sm)
    }

    private func generateRoute() {
        let allBars = barRepository.bars
        guard allBars.count >= 3 else {
            selectedRoute = allBars
            return
        }

        guard let userLocation = originLocation else {
            locationService.requestPermission()
            toastCenter.show(
                String(localized: "Enable location access or choose a place to generate a route."),
                kind: .info
            )
            return
        }

        let nearby = barRepository.nearbyBars(
            coordinate: userLocation.coordinate,
            radius: BarRepository.walkingCrawlRadius
        )
        .sorted {
            DistanceService.distance(from: userLocation, to: $0)
                < DistanceService.distance(from: userLocation, to: $1)
        }

        guard nearby.count >= 3 else {
            toastCenter.show(
                String(localized: "Not enough bars within walking distance yet."),
                kind: .info
            )
            return
        }

        selectedRoute = Array(nearby.prefix(10).shuffled().prefix(3))
    }
}

// MARK: - Crawl route map

/// Renders the generated crawl as a numbered route on a map, with a
/// one-tap shortcut into walking directions in Maps.
struct CrawlRouteView: View {

    let stops: [Bar]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            CrawlMapRepresentable(stops: stops)
                .ignoresSafeArea()
                .navigationTitle(String(localized: "Your Crawl"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            openWalkingDirections()
                        } label: {
                            Label(String(localized: "Directions"), systemImage: "arrow.triangle.turn.up.right.diamond")
                        }
                        .disabled(stops.count < 2)
                    }
                }
        }
    }

    private func openWalkingDirections() {
        guard stops.count >= 2 else { return }

        let items = stops.map { bar -> MKMapItem in
            let item = MKMapItem(
                placemark: MKPlacemark(coordinate: bar.coordinate)
            )
            item.name = bar.name
            return item
        }

        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ]
        MKMapItem.openMaps(with: items, launchOptions: options)
    }
}

private struct CrawlMapRepresentable: UIViewRepresentable {

    let stops: [Bar]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Only recompute when the stops actually change.
        let ids = stops.map(\.id)
        guard context.coordinator.stopIDs != ids else { return }
        context.coordinator.stopIDs = ids

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        for (index, bar) in stops.enumerated() {
            let annotation = MKPointAnnotation()
            annotation.coordinate = bar.coordinate
            annotation.title = "\(index + 1). \(bar.name)"
            map.addAnnotation(annotation)
        }

        guard stops.count >= 2 else {
            if let first = stops.first {
                let region = MKCoordinateRegion(
                    center: first.coordinate,
                    latitudinalMeters: 800,
                    longitudinalMeters: 800
                )
                map.setRegion(region, animated: true)
            }
            return
        }

        // Fit the straight-line extent right away so the map isn't blank,
        // then refine to the real walking routes as they arrive.
        var coords = stops.map { $0.coordinate }
        let roughExtent = MKPolyline(coordinates: &coords, count: coords.count)
        map.setVisibleMapRect(
            roughExtent.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40),
            animated: false
        )

        context.coordinator.fetchWalkingRoutes(for: stops, on: map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {

        var stopIDs: [UUID] = []

        private var remainingLegs = 0
        private var routesRect = MKMapRect.null

        /// Requests real walking directions between each pair of
        /// consecutive stops and draws them as route polylines.
        func fetchWalkingRoutes(for stops: [Bar], on map: MKMapView) {
            remainingLegs = stops.count - 1
            routesRect = MKMapRect.null

            for index in 0..<(stops.count - 1) {
                let from = stops[index]
                let to = stops[index + 1]

                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
                request.transportType = .walking
                request.requestsAlternateRoutes = false

                let directions = MKDirections(request: request)
                directions.calculate { [weak self] response, _ in
                    guard let self else { return }

                    DispatchQueue.main.async {
                        self.remainingLegs -= 1

                        if let route = response?.routes.first {
                            map.addOverlay(route.polyline, level: .aboveRoads)

                            self.routesRect = self.routesRect.isNull
                                ? route.polyline.boundingMapRect
                                : self.routesRect.union(route.polyline.boundingMapRect)
                        }

                        if self.remainingLegs == 0 && !self.routesRect.isNull {
                            map.setVisibleMapRect(
                                self.routesRect,
                                edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40),
                                animated: true
                            )
                        }
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(
                red: 0x6B / 255,
                green: 0x27 / 255,
                blue: 0x37 / 255,
                alpha: 1
            )
            renderer.lineWidth = 4
            return renderer
        }
    }
}
