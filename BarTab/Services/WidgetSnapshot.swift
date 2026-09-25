import Foundation

/// Shared between the app and the widget extension via an App Group.
///
/// The app computes a small snapshot of the most useful bits (cheapest
/// beer, next crawl stop) and writes it to the group container; the
/// widget reads it back without needing its own auth/network/location.
enum WidgetConstants {
    static let appGroupID = "group.com.bartap.app"
    static let snapshotKey = "widgetSnapshot"
}

struct WidgetSnapshot: Codable, Equatable {
    var cheapestBeer: CheapestBeer?
    var nextCrawlStop: NextCrawlStop?
    var updatedAt: Date

    struct CheapestBeer: Codable, Equatable {
        let barName: String
        let amount: Double
        let currency: String
        let distanceLabel: String?
    }

    struct NextCrawlStop: Codable, Equatable {
        let groupName: String
        let eventTitle: String
        let barName: String
        let stopIndex: Int
        let stopCount: Int
        let goingCount: Int
    }

    static var empty: WidgetSnapshot {
        WidgetSnapshot(cheapestBeer: nil, nextCrawlStop: nil, updatedAt: Date())
    }
}

enum WidgetDataStore {
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupID)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: WidgetConstants.snapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: WidgetConstants.snapshotKey)
    }
}
