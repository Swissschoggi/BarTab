import Foundation

enum DrinkSize: String, Codable, CaseIterable, Hashable {

    // Volume-based
    case oneDeciliter
    case twoDeciliters
    case threeDeciliters
    case fiveDeciliters

    case twentyCentiliters
    case twentyFiveCentiliters
    case thirtyThreeCentiliters
    case fiftyCentiliters

    case shot
    case bottle
    case glass
    case other

    var displayName: String {
        switch self {
        case .oneDeciliter:
            return String(localized: "1 dl")

        case .twoDeciliters:
            return String(localized: "2 dl")

        case .threeDeciliters:
            return String(localized: "3 dl")

        case .fiveDeciliters:
            return String(localized: "5 dl")

        case .twentyCentiliters:
            return String(localized: "20 cl")

        case .twentyFiveCentiliters:
            return String(localized: "25 cl")

        case .thirtyThreeCentiliters:
            return String(localized: "33 cl")

        case .fiftyCentiliters:
            return String(localized: "50 cl")

        case .shot:
            return String(localized: "Shot")

        case .bottle:
            return String(localized: "Bottle")

        case .glass:
            return String(localized: "Glass")

        case .other:
            return String(localized: "Other")
        }
    }

    var isVolumeBased: Bool {
        volumeInMilliliters != nil
    }

    /// Standard volume in millilitres for sizes that have one. Bottles,
    /// glasses, shots and "other" are intentionally nil because their
    /// volume varies too much to compare fairly.
    var volumeInMilliliters: Int? {
        switch self {
        case .oneDeciliter: return 100
        case .twoDeciliters: return 200
        case .threeDeciliters: return 300
        case .fiveDeciliters: return 500
        case .twentyCentiliters: return 200
        case .twentyFiveCentiliters: return 250
        case .thirtyThreeCentiliters: return 330
        case .fiftyCentiliters: return 500
        case .shot, .bottle, .glass, .other: return nil
        }
    }

    /// Volume in decilitres, for older call sites. 1 dl = 100 ml.
    var volumeInDeciliters: Double? {
        volumeInMilliliters.map { Double($0) / 100 }
    }
}
