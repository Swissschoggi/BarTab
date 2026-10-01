import Foundation
import CoreLocation
import Combine

final class LiveLocationService: ObservableObject {

    static let shared = LiveLocationService()

    @Published private(set) var friendsLocations: [UUID: LiveLocation] = [:]
    @Published private(set) var isSharing = false

    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let locationService = LocationService.shared

    private init() {
        locationService.$location
            .compactMap { $0 }
            .throttle(for: 10, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }

    func startSharing() {
        guard !isSharing, SupabaseClient.shared.currentUserID != nil else { return }
        isSharing = true
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pushLocationToSupabase()
            }
        }
        updateTimer?.fire()
    }

    func stopSharing() {
        isSharing = false
        updateTimer?.invalidate()
        updateTimer = nil
        Task { await clearLocationFromSupabase() }
    }

    func subscribeToFriends() {
        // TODO: Use Supabase Realtime to subscribe to live_locations table
        // For now, poll every 60 seconds
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchFriendsLocations()
            }
        }.fire()
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isSharing else { return }
        // Update local state immediately for smooth map animation
        if let userID = SupabaseClient.shared.currentUserID {
            friendsLocations[userID] = LiveLocation(
                userID: userID,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy,
                updatedAt: Date()
            )
        }
    }

    private func pushLocationToSupabase() async {
        guard isSharing,
              let userID = SupabaseClient.shared.currentUserID,
              let location = locationService.location else { return }

        do {
            try await SupabaseClient.shared.upsertLiveLocation(
                userID: userID,
                coordinate: location.coordinate,
                accuracy: location.horizontalAccuracy
            )
        } catch {
            print("Failed to push live location: \(error)")
        }
    }

    private func clearLocationFromSupabase() async {
        guard let userID = SupabaseClient.shared.currentUserID else { return }
        do {
            try await SupabaseClient.shared.deleteLiveLocation(userID: userID)
        } catch {
            print("Failed to clear live location: \(error)")
        }
    }

    private func fetchFriendsLocations() async {
        guard let userID = SupabaseClient.shared.currentUserID else { return }
        do {
            let locations = try await SupabaseClient.shared.fetchLiveLocations(
                for: userID
            )
            friendsLocations = Dictionary(uniqueKeysWithValues: locations.map { ($0.userID, $0) })
        } catch {
            print("Failed to fetch friends locations: \(error)")
        }
    }
}

struct LiveLocation: Codable, Identifiable {
    let userID: UUID
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let updatedAt: Date

    var id: UUID { userID }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 120 // 2 minutes
    }
}