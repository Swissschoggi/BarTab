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
        case .tap: return "drop.fill"
        case .bottle: return "wineglass.fill"
        case .can: return "cube.fill"
        case .glass: return "cup.and.saucer.fill"
        }
    }
}
