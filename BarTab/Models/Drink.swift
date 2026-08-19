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
            return "Beer"
        case .wine:
            return "Wine"
        case .cocktail:
            return "Cocktail"
        case .shot:
            return "Shot"
        case .softDrink:
            return "Soft Drink"
        case .coffee:
            return "Coffee"
        case .other:
            return "Other"
        }
    }
}
