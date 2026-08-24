import Foundation

enum Drink: String, Codable, CaseIterable {
    case beer
    case wine
    case cocktail
    case shot
    case softDrink
    case coffee
    case other
    
    var displayName: String {
        switch self {
        case .beer:
            return String(localized: "Beer")
        case .wine:
            return String(localized: "Wine")
        case .cocktail:
            return String(localized: "Cocktail")
        case .shot:
            return String(localized: "Shot")
        case .softDrink:
            return String(localized: "Soft Drink")
        case .coffee:
            return String(localized: "Coffee")
        case .other:
            return String(localized: "Other")
        }
    }
}
