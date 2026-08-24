import Foundation

/// Preset ambience styles that users can choose from when rating a bar.
enum AmbienceStyle: String, CaseIterable, Identifiable, Codable {
    case cozy
    case modern
    case elegant
    case casual
    case rustic
    case trendy
    case lively
    case chill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cozy: return "Cozy"
        case .modern: return "Modern"
        case .elegant: return "Elegant"
        case .casual: return "Casual"
        case .rustic: return "Rustic"
        case .trendy: return "Trendy"
        case .lively: return "Lively"
        case .chill: return "Chill"
        }
    }

    var icon: String {
        switch self {
        case .cozy: return "flame.fill"
        case .modern: return "sparkles"
        case .elegant: return "star.circle.fill"
        case .casual: return "cup.and.saucer.fill"
        case .rustic: return "leaf.fill"
        case .trendy: return "bolt.heart.fill"
        case .lively: return "music.note"
        case .chill: return "moon.fill"
        }
    }
}
