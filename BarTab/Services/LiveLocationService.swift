import Foundation
import CoreLocation
import Combine

final class LiveLocationService: ObservableObject {

    static let shared = LiveLocationService()

    @Published private(set) var friendsLocations: [UUID: LiveLocation] = [:]
    @Published private(set) var isSharing = false

    private static let sharingKey = "com.Bartap.liveLocationSharing"
    private static let sharingUserKey = "com.Bartap.liveLocationSharingUserID"

    private var updateTimer: Timer?
    private var friendsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let locationService = LocationService.shared

    /// The account that opted into sharing. Persisted alongside the
    /// sharing flag so a different account signing in on the same
    /// device can never inherit the previous user's sharing state.
    private var sharingUserID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.sharingUserKey) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: Self.sharingUserKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.sharingUserKey)
            }
        }
    }

    private init() {
        let savedSharing = UserDefaults.standard.bool(forKey: Self.sharingKey)
        let currentUserID = SupabaseClient.shared.currentUserID

        if savedSharing,
           let currentUserID,
           sharingUserID == currentUserID {
            isSharing = true
        } else {
            // Stale flag from a previous account or a signed-out state.
            isSharing = false
            UserDefaults.standard.set(false, forKey: Self.sharingKey)
            sharingUserID = nil
        }

        locationService.$location
            .compactMap { $0 }
            .throttle(for: 10, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)

        if isSharing {
            startTimer()
        }
    }

    deinit {
        updateTimer?.invalidate()
        friendsTimer?.invalidate()
    }

    func startSharing() {
        guard !isSharing,
              let userID = SupabaseClient.shared.currentUserID else { return }
        isSharing = true
        sharingUserID = userID
        UserDefaults.standard.set(true, forKey: Self.sharingKey)
        startTimer()
    }

    /// Stops sharing locally right away and clears the remote row.
    func stopSharing() {
        let userID = SupabaseClient.shared.currentUserID ?? sharingUserID
        let wasSharing = isSharing
        stopSharingLocally()
        guard wasSharing else { return }
        Task { await clearRemoteLocation(for: userID) }
    }

    /// Stops sharing and waits for the remote location to be deleted.
    /// Call this *before* clearing the auth session (logout/deletion).
    func stopSharingAndClearRemote() async {
        let userID = SupabaseClient.shared.currentUserID ?? sharingUserID
        let wasSharing = isSharing
        stopSharingLocally()
        guard wasSharing else { return }
        await clearRemoteLocation(for: userID)
    }

    /// Resets local sharing state without a network call. Safe to call
    /// on logout, account switch, or when the session is already gone.
    func stopSharingLocally() {
        isSharing = false
        UserDefaults.standard.set(false, forKey: Self.sharingKey)
        sharingUserID = nil
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Called whenever the signed-in account changes. Prevents a new
    /// account from inheriting the previous account's sharing flag or
    /// cached friends' locations.
    func reconcileAccount(with userID: UUID?) {
        if userID == nil {
            stopSharingLocally()
            unsubscribeFromFriends()
            friendsLocations = [:]
            return
        }

        if isSharing, sharingUserID != userID {
            stopSharingLocally()
            unsubscribeFromFriends()
        } else if !isSharing, sharingUserID != nil {
            sharingUserID = nil
            unsubscribeFromFriends()
        }

        friendsLocations = [:]
    }

    func clearFriendsLocations() {
        friendsLocations = [:]
    }

    private func startTimer() {
        guard let userID = SupabaseClient.shared.currentUserID else {
            stopSharingLocally()
            return
        }
        sharingUserID = userID

        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.pushLocationToSupabase()
            }
        }
        updateTimer?.fire()
    }

    func subscribeToFriends() {
        // Poll for now; a future version can use Supabase Realtime.
        friendsTimer?.invalidate()
        friendsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchFriendsLocations()
            }
        }
        friendsTimer?.fire()
    }

    func unsubscribeFromFriends() {
        friendsTimer?.invalidate()
        friendsTimer = nil
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isSharing,
              let userID = SupabaseClient.shared.currentUserID,
              sharingUserID == userID else { return }

        // Update local state immediately for smooth map animation.
        friendsLocations[userID] = LiveLocation(
            userID: userID,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            updatedAt: Date()
        )
    }

    private func pushLocationToSupabase() async {
        guard isSharing,
              let userID = SupabaseClient.shared.currentUserID,
              sharingUserID == userID,
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

    private func clearRemoteLocation(for userID: UUID?) async {
        guard let userID else { return }

        // The request is authenticated with the current access token, so
        // only clear a row that belongs to the account still signed in.
        guard SupabaseClient.shared.currentUserID == userID else { return }

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