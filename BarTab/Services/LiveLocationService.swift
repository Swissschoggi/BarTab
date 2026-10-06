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

    // Supabase Realtime subscription (friends' live locations).
    private var friendsPollTimer: Timer?
    private var realtimeTask: URLSessionWebSocketTask?
    private var realtimeSession: URLSession?
    private var realtimeHeartbeat: Timer?
    private var realtimeRef = 0
    private var realtimeConnected = false

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
            guard let self else { return }
            Task { @MainActor in
                await self.pushLocationToSupabase()
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
        // Populate immediately, then switch to live updates once the
        // realtime socket connects (the poll stays as a fallback).
        Task { @MainActor in await fetchFriendsLocations() }
        startFriendsPoll()
        connectRealtime()
    }

    // MARK: - Realtime

    private func connectRealtime() {
        guard realtimeTask == nil,
              let token = AuthTokenStore.shared.accessToken else { return }

        let host = SupabaseConfig.projectURL.host ?? ""
        guard let url = URL(
            string: "wss://\(host)/realtime/v1/websocket?apikey=\(SupabaseConfig.anonKey)&vsn=1.0.0"
        ) else { return }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        realtimeSession = session
        realtimeTask = task
        task.resume()

        joinRealtime()
        receiveRealtime()
    }

    private func joinRealtime() {
        realtimeRef += 1
        sendRealtime([
            "topic": "realtime:public:live_locations",
            "event": "phx_join",
            "payload": [
                "config": [
                    "postgres_changes": [
                        ["event": "*", "schema": "public", "table": "live_locations"]
                    ]
                ],
                "access_token": AuthTokenStore.shared.accessToken ?? ""
            ],
            "ref": "\(realtimeRef)"
        ])
    }

    private func sendRealtime(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        realtimeTask?.send(.string(text)) { _ in }
    }

    private func receiveRealtime() {
        realtimeTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleRealtimeMessage(message)
                self.receiveRealtime()
            case .failure:
                self.realtimeDisconnected()
            }
        }
    }

    private func handleRealtimeMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        switch event {
        case "phx_reply":
            let status = (json["payload"] as? [String: Any])?["status"] as? String
            if status == "ok" {
                realtimeConnected = true
                startRealtimeHeartbeat()
                stopFriendsPoll()
            } else {
                realtimeDisconnected()
            }
        case "postgres_changes":
            handleRealtimeChange(json["payload"])
        case "phx_error", "phx_close":
            realtimeDisconnected()
        default:
            break
        }
    }

    private func handleRealtimeChange(_ payload: Any?) {
        guard let dict = payload as? [String: Any],
              let data = dict["data"] as? [String: Any],
              let eventType = data["eventType"] as? String else { return }

        switch eventType {
        case "INSERT", "UPDATE":
            if let record = data["new"] as? [String: Any],
               let location = Self.liveLocation(from: record) {
                DispatchQueue.main.async { [weak self] in
                    self?.friendsLocations[location.userID] = location
                }
            }
        case "DELETE":
            if let record = data["old"] as? [String: Any],
               let userID = Self.userID(from: record) {
                DispatchQueue.main.async { [weak self] in
                    self?.friendsLocations.removeValue(forKey: userID)
                }
            }
        default:
            break
        }
    }

    private func startRealtimeHeartbeat() {
        realtimeHeartbeat?.invalidate()
        realtimeHeartbeat = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendRealtime([
                "topic": "phoenix",
                "event": "heartbeat",
                "payload": [:],
                "ref": "\(self?.realtimeRef ?? 0)"
            ])
        }
    }

    private func realtimeDisconnected() {
        realtimeConnected = false
        realtimeHeartbeat?.invalidate()
        realtimeHeartbeat = nil
        realtimeTask?.cancel(with: .normalClosure, reason: nil)
        realtimeTask = nil
        realtimeSession = nil

        startFriendsPoll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.connectRealtime()
        }
    }

    // MARK: - Poll fallback

    private func startFriendsPoll() {
        guard friendsPollTimer == nil else { return }
        friendsPollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.fetchFriendsLocations() }
        }
    }

    private func stopFriendsPoll() {
        friendsPollTimer?.invalidate()
        friendsPollTimer = nil
    }

    // MARK: - Decoding

    private static func liveLocation(from record: [String: Any]) -> LiveLocation? {
        guard let userID = userID(from: record),
              let latitude = number(from: record["latitude"]),
              let longitude = number(from: record["longitude"]) else { return nil }
        let accuracy = number(from: record["accuracy"]) ?? 0
        let updatedAt = date(from: record["updated_at"] as? String) ?? Date()
        return LiveLocation(
            userID: userID,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            updatedAt: updatedAt
        )
    }

    private static func userID(from record: [String: Any]) -> UUID? {
        (record["user_id"] as? String).flatMap(UUID.init(uuidString:))
    }

    private static func number(from any: Any?) -> Double? {
        (any as? NSNumber)?.doubleValue
    }

    private static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
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