import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var liveLocationService: LiveLocationService

    @State private var showingAddBar = false
    @State private var showingBarHop = false
    @State private var showingShareSheet = false

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var selectedBar: Bar?
    @State private var selectedFriend: LiveLocation?

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

    private var activeFriends: [LiveLocation] {
        liveLocationService.friendsLocations.values
            .filter { !$0.isStale }
            .filter { $0.userID != userSession.currentUser?.id }
    }

    private var mapItems: [MapItem] {
        let bars = visibleBars.map(MapItem.bar)
        let friends = activeFriends.map(MapItem.friend)
        return bars + friends
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            Map(coordinateRegion: $region, annotationItems: mapItems) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    annotationContent(for: item)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: BarTabSpacing.sm) {

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
                    showingBarHop = true
                } label: {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.barTabPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                }
                .accessibilityLabel("Bar hop")

                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: liveLocationService.isSharing ? "location.fill.viewfinder" : "location.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(liveLocationService.isSharing ? .barTabAccent : .barTabPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                .stroke(liveLocationService.isSharing ? Color.barTabAccent : Color.clear, lineWidth: 2)
                        )
                }
                .accessibilityLabel(liveLocationService.isSharing ? "Stop sharing location" : "Share my location")

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
            liveLocationService.subscribeToFriends()
        }
        .onReceive(locationService.$location) { location in
            guard let location = location else { return }
            guard !hasCenteredOnUser else { return }
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
                    .environmentObject(locationService)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedFriend) { friend in
            NavigationView {
                FriendLocationView(friend: friend)
                    .environmentObject(userSession)
                    .environmentObject(barRepository)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBarHop) {
            BarHopView()
                .environmentObject(barRepository)
                .environmentObject(locationService)
                .environmentObject(toastCenter)
        }
        .sheet(isPresented: $showingAddBar) {
            AddBarView(onBarAdded: { bar in
                teleport(to: bar)
            })
            .environmentObject(barRepository)
            .environmentObject(userSession)
            .environmentObject(toastCenter)
        }
        .confirmationDialog(
            liveLocationService.isSharing ? "Stop sharing location?" : "Share my location?",
            isPresented: $showingShareSheet,
            titleVisibility: .visible
        ) {
            if liveLocationService.isSharing {
                Button("Stop sharing", role: .destructive) {
                    liveLocationService.stopSharing()
                    toastCenter.show("Location sharing stopped", kind: .info)
                }
            } else {
                Button("Start sharing") {
                    liveLocationService.startSharing()
                    toastCenter.show("Sharing location with friends", kind: .success)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(liveLocationService.isSharing
                ? "Friends will no longer see your location on the map."
                : "Friends you follow will see your real-time location on their map for 2 minutes after each update.")
        }
    }

    private func centerOnUser() {
        guard let location = locationService.location else { return }
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

    // MARK: - Annotations

    @ViewBuilder
    private func annotationContent(for item: MapItem) -> some View {
        switch item {
        case .bar(let bar):
            barAnnotation(bar)
        case .friend(let friend):
            friendAnnotation(friend)
        }
    }

    private func barAnnotation(_ bar: Bar) -> some View {
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

    private func friendAnnotation(_ friend: LiveLocation) -> some View {
        Button {
            HapticEngine.lightTap()
            selectedFriend = friend
        } label: {
            ZStack {
                Circle()
                    .fill(Color.barTabAccent)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(radius: 3)

                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.barTabAccent)
                    )
            }
        }
        .accessibilityLabel("Friend at \(friend.coordinate.latitude), \(friend.coordinate.longitude)")
    }
}

private enum MapItem: Identifiable {
    case bar(Bar)
    case friend(LiveLocation)

    var id: String {
        switch self {
        case .bar(let bar): return "bar-\(bar.id.uuidString)"
        case .friend(let friend): return "friend-\(friend.userID.uuidString)"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .bar(let bar): return bar.coordinate
        case .friend(let friend): return friend.coordinate
        }
    }
}

private struct FriendLocationView: View {
    let friend: LiveLocation
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: BarTabSpacing.md) {
            HStack(spacing: 12) {
                UserAvatarView(
                    urlString: nil,
                    displayName: nil,
                    size: 50
                )
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Friend"))
                        .font(.barTabHeading)
                        .foregroundColor(.barTabText)

                    Text(friend.isStale ? String(localized: "Location stale") : String(localized: "Live now"))
                        .font(.barTabCaption)
                        .foregroundColor(friend.isStale ? .barTabSecondary : .barTabAccent)

                    if let bar = nearestBar() {
                        Text("Near \(bar.name)")
                            .font(.barTabSmall)
                            .foregroundColor(.barTabSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, BarTabSpacing.md)

            if !friend.isStale {
                ZStack {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: friend.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )))
                    .frame(height: 200)

                    Circle()
                        .fill(Color.barTabAccent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous))
                .padding(.horizontal, BarTabSpacing.md)
            }

            Spacer()
        }
        .padding(.vertical, BarTabSpacing.md)
    }

    private func nearestBar() -> Bar? {
        let friendLoc = CLLocation(latitude: friend.latitude, longitude: friend.longitude)
        return barRepository.bars
            .min { a, b in
                let da = DistanceService.distance(from: friendLoc, to: a)
                let db = DistanceService.distance(from: friendLoc, to: b)
                return da < db
            }
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
