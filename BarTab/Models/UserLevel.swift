import Foundation

/// Contribution levels based on how many prices and bars a user has added.
enum UserLevel: Int, CaseIterable, Identifiable {
    case newcomer = 0
    case regular = 5
    case contributor = 15
    case expert = 30
    case legend = 60

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .newcomer: return String(localized: "Newcomer")
        case .regular: return String(localized: "Regular")
        case .contributor: return String(localized: "Contributor")
        case .expert: return String(localized: "Expert")
        case .legend: return String(localized: "Legend")
        }
    }

    var icon: String {
        switch self {
        case .newcomer: return "leaf.fill"
        case .regular: return "star.fill"
        case .contributor: return "rosette.fill"
        case .expert: return "crown.fill"
        case .legend: return "sparkles"
        }
    }

    /// The threshold to reach this level (cumulative contributions).
    var threshold: Int { rawValue }

    /// Progress to the next level (0.0 ... 1.0).
    static func progress(for contributions: Int) -> Double {
        let allCases = UserLevel.allCases
        for (index, level) in allCases.enumerated() {
            if contributions < level.threshold {
                let prev = index > 0 ? allCases[index - 1].threshold : 0
                let range = Double(level.threshold - prev)
                return Double(contributions - prev) / range
            }
        }
        return 1.0
    }

    /// The current level for a given contribution count.
    static func current(for contributions: Int) -> UserLevel {
        var result: UserLevel = .newcomer
        for level in UserLevel.allCases {
            if contributions >= level.threshold {
                result = level
            }
        }
        return result
    }

    /// Contributions needed to reach the next level.
    static func remaining(for contributions: Int) -> Int? {
        for level in UserLevel.allCases {
            if contributions < level.threshold {
                return level.threshold - contributions
            }
        }
        return nil
    }
}
