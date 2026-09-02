import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationService: LocationService

    @State private var showingAddBar = false

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var selectedBar: Bar?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 47.3769,
            longitude: 8.5417
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 0.01,
            longitudeDelta: 0.01
        )
    )

    @State private var hasCenteredOnUser = false

    private var visibleBars: [Bar] {
        barRepository.bars.filter { !barRepository.isBarAutoHidden($0) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {


            Map(coordinateRegion: $region, annotationItems: visibleBars) { bar in
                MapAnnotation(coordinate: bar.coordinate) {
                    Button {
                        HapticEngine.lightTap()
                        selectedBar = bar
                    } label: {
                        VStack(spacing: 2) {

                            if let level = barRepository.priceLevel(for: bar) {
                                Text(level)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.barTabAccent)
                                    .clipShape(Capsule())
                            }

                            Image(systemName: "wineglass.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.barTabPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))

                            Image(systemName: "triangle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.barTabPrimary)
                                .rotationEffect(.degrees(180))
                        }
                    }
                    .accessibilityLabel("\(bar.name), \(bar.address)")
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 10) {

                Button {
                    showingAddBar = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.barTabPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                }
                .accessibilityLabel("Add bar")

                Button {
                    centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.barTabPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                }
                .accessibilityLabel("Center on my location")
            }
            .padding()
        }
        .onAppear {
            locationService.requestPermission()
        }
        .onReceive(locationService.$location) { location in
            guard let location = location else {
                return
            }

            guard !hasCenteredOnUser else {
                return
            }

            DispatchQueue.main.async {
                centerMap(on: location)
                hasCenteredOnUser = true
            }
        }
        .sheet(item: $selectedBar) { bar in
            NavigationView {
                BarView(bar: bar, allowsDismissal: true)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddBar) {
            AddBarView(onBarAdded: { bar in
                teleport(to: bar)
            })
            .environmentObject(barRepository)
            .environmentObject(userSession)
            .environmentObject(toastCenter)
        }
    }


    private func centerOnUser() {
        guard let location = locationService.location else {
            return
        }

        centerMap(on: location)
    }

    private func centerMap(on location: CLLocation) {
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        )
    }

    /// Jumps the map to a newly created bar and opens its detail sheet.
    private func teleport(to bar: Bar) {
        withAnimation {
            region = MKCoordinateRegion(
                center: bar.coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.01,
                    longitudeDelta: 0.01
                )
            )
        }

        selectedBar = bar
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environmentObject(BarRepository())
            .environmentObject(UserSession())
            .environmentObject(ToastCenter())
    }
}
