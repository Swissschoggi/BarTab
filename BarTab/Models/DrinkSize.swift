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
            return "1 dl"

        case .twoDeciliters:
            return "2 dl"

        case .threeDeciliters:
            return "3 dl"

        case .fiveDeciliters:
            return "5 dl"

        case .twentyCentiliters:
            return "20 cl"

        case .twentyFiveCentiliters:
            return "25 cl"

        case .thirtyThreeCentiliters:
            return "33 cl"

        case .fiftyCentiliters:
            return "50 cl"

        case .shot:
            return "Shot"

        case .bottle:
            return "Bottle"

        case .glass:
            return "Glass"

        case .other:
            return "Other"
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
