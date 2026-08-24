import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var locationService = LocationService()

    @State private var showingAddBar = false

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {


            Map(
                coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: barRepository.bars
            ) { bar in
                MapAnnotation(coordinate: bar.coordinate) {
                    Button {
                        selectedBar = bar
                    } label: {
                        Image(systemName: "wineglass.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.barTabPrimary)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {

                Button {
                    showingAddBar = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.barTabPrimary)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }

                Button {
                    centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.barTabPrimary)
                        .frame(width: 50, height: 50)
                        .background(Color.barTabBackground)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
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
    }
}
