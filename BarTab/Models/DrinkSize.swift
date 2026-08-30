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
        switch self {
        case .oneDeciliter,
             .twoDeciliters,
             .threeDeciliters,
             .fiveDeciliters,
             .twentyCentiliters,
             .twentyFiveCentiliters,
             .thirtyThreeCentiliters,
             .fiftyCentiliters:
            return true

        case .shot,
             .bottle,
             .glass,
             .other:
            return false
        }
    }

    /// Approximate volume in centiliters. Used to normalize prices so a
    /// bottle isn't compared one-to-one against a glass. Returns nil for
    /// sizes where a meaningful volume can't be estimated.
    func volumeInCentiliters(for drink: Drink) -> Double? {
        switch self {
        case .oneDeciliter:
            return 10
        case .twoDeciliters:
            return 20
        case .threeDeciliters:
            return 30
        case .fiveDeciliters:
            return 50
        case .twentyCentiliters:
            return 20
        case .twentyFiveCentiliters:
            return 25
        case .thirtyThreeCentiliters:
            return 33
        case .fiftyCentiliters:
            return 50
        case .shot:
            return 4
        case .bottle:
            switch drink {
            case .wine:
                return 75
            case .beer:
                return 33
            case .softDrink:
                return 50
            default:
                return 70
            }
        case .glass:
            switch drink {
            case .wine:
                return 15
            case .beer:
                return 30
            case .cocktail:
                return 20
            case .softDrink:
                return 25
            case .coffee:
                return 25
            default:
                return 15
            }
        case .other:
            return nil
        }
    }
}
