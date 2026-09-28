import Foundation

/// How a drink is served.
enum ServingMethod: String, Codable, CaseIterable, Identifiable {
    case tap
    case bottle
    case can
    case glass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tap: return String(localized: "Tap")
        case .bottle: return String(localized: "Bottle")
        case .can: return String(localized: "Can")
        case .glass: return String(localized: "Glass")
        }
    }

    var icon: String {
        switch self {
        case .tap: return "spigot.fill"
        case .bottle: return "waterbottle.fill"
        case .can: return "cylinder.fill"
        case .glass: return "wineglass.fill"
        }
    }
}
