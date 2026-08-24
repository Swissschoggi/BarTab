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
}
