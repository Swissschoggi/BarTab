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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.barTabTitle)
                                .foregroundColor(.barTabPrimary)
                            Text(String(localized: "Bar Hop Generator"))
                                .font(.barTabStat)
                                .foregroundColor(.barTabText)
                        }

                        Text(String(localized: "Let BarTab curate a 3-stop walking crawl featuring great drink deals near you."))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)
                    }
                    .barTabCard()

                    Menu {
                        Button {
                            crawlOrigin = nil
                            originName = ""
                        } label: {
                            Label(String(localized: "My location"), systemImage: "location.fill")
                        }

                        Button {
                            showingLocationPicker = true
                        } label: {
                            Label(String(localized: "Choose a place…"), systemImage: "mappin.and.ellipse")
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: crawlOrigin == nil ? "location.fill" : "mappin.circle.fill")
                                .font(.barTabBody)
                                .foregroundColor(.barTabPrimary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(String(localized: "Searching near"))
                                    .font(.barTabTiny)
                                    .foregroundColor(.barTabSecondary)
                                Text(originLabel)
                                    .font(.barTabBodySemibold)
                                    .foregroundColor(.barTabText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.barTabTiny)
                                .foregroundColor(.barTabSecondary)
                        }
                        .padding(.horizontal, BarTabSpacing.md)
                        .padding(.vertical, BarTabSpacing.sm)
                        .background(Color.barTabCardFill)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                        )
                    }

                    if selectedRoute.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "map.fill")
                                .font(.barTabEmptyIconLarge)
                                .foregroundColor(.barTabPrimary.opacity(0.6))

                            Text(String(localized: "Ready for a night out?"))
                                .font(.barTabHeading)
                                .foregroundColor(.barTabText)

                            Button {
                                generateRoute()
                            } label: {
                                Text(String(localized: "Generate Route"))
                                    .barTabPrimaryButton()
                            }
                            .padding(.horizontal, 40)

                            if originLocation == nil {
                                Text(String(localized: "Enable location access or pick a place to find bars."))
                                    .font(.barTabCaption)
                                    .foregroundColor(.barTabSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .barTabCard()
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(String(localized: "Your Crawl Route"))
                                    .font(.barTabHeading)
                                    .foregroundColor(.barTabText)

                                Spacer()

                                Button(String(localized: "Shuffle")) {
                                    generateRoute()
                                }
                                .font(.barTabCaption)
                                .foregroundColor(.barTabPrimary)
                            }

                            ForEach(Array(selectedRoute.enumerated()), id: \.element.id) { index, bar in
                                HStack(alignment: .top, spacing: BarTabSpacing.sm) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.barTabPrimary)
                                            .frame(width: 32, height: 32)
                                        Text("\(index + 1)")
                                            .font(.barTabBodySemibold)
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bar.name)
                                            .font(.barTabBodySemibold)
                                            .foregroundColor(.barTabText)

                                        Text(bar.address)
                                            .font(.barTabCaption)
                                            .foregroundColor(.barTabSecondary)

                                        if let popular = barRepository.popularAmbience(for: bar) {
                                            HStack(spacing: 4) {
                                                Image(systemName: popular.icon)
                                                    .font(.barTabTiny)
                                                Text(popular.displayName)
                                                    .font(.barTabTiny)
                                            }
                                            .foregroundColor(.barTabPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.barTabPrimary.opacity(0.08))
                                            .clipShape(Capsule())
                                            .padding(.top, 4)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.barTabCardFill)
                                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                        .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                                )
                            }

                            Button {
                                generateRoute()
                            } label: {
                                Text(String(localized: "Try Another Route"))
                                    .barTabPrimaryButton()
                            }
                            .padding(.top, 8)

                            Button {
                                showingRouteMap = true
                            } label: {
                                Label(String(localized: "Show route on map"), systemImage: "map.fill")
                                    .barTabSecondaryButton()
                            }
                        }
                        .barTabCard()
                    }
                }
                .padding(16)
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
        .onChange(of: crawlOrigin) { _ in
            generateRoute()
        }
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

        var coordinates = stops.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        map.addOverlay(polyline)

        map.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 80, right: 40),
            animated: true
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
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
            renderer.lineDashPattern = [0, 8]
            return renderer
        }
    }
}
