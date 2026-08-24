import Foundation

/// Subcategories for drinks (e.g. beer styles, wine types).
enum DrinkStyle: String, Codable, CaseIterable, Identifiable {

    // Beer styles
    case pilsener
    case ipa
    case stout
    case lager
    case wheatBeer
    case paleAle
    case amberAle
    case porter
    case sour
    case blonde

    // Wine types
    case red
    case white
    case rose
    case sparkling
    case dessert
    case orange

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pilsener: return String(localized: "Pilsener")
        case .ipa: return String(localized: "IPA")
        case .stout: return String(localized: "Stout")
        case .lager: return String(localized: "Lager")
        case .wheatBeer: return String(localized: "Wheat Beer")
        case .paleAle: return String(localized: "Pale Ale")
        case .amberAle: return String(localized: "Amber Ale")
        case .porter: return String(localized: "Porter")
        case .sour: return String(localized: "Sour")
        case .blonde: return String(localized: "Blonde")
        case .red: return String(localized: "Red")
        case .white: return String(localized: "White")
        case .rose: return String(localized: "Rosé")
        case .sparkling: return String(localized: "Sparkling")
        case .dessert: return String(localized: "Dessert")
        case .orange: return String(localized: "Orange")
        }
    }

    /// Which drink category this style belongs to.
    var parentDrink: Drink {
        switch self {
        case .pilsener, .ipa, .stout, .lager, .wheatBeer,
             .paleAle, .amberAle, .porter, .sour, .blonde:
            return .beer
        case .red, .white, .rose, .sparkling, .dessert, .orange:
            return .wine
        }
    }

    /// Styles available for a given drink type.
    static func styles(for drink: Drink) -> [DrinkStyle] {
        allCases.filter { $0.parentDrink == drink }
    }
}
