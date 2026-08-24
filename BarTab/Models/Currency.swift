import Foundation

/// Supported currencies for the app.
enum Currency: String, CaseIterable, Identifiable, Codable {
    case chf = "CHF"
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case pln = "PLN"
    case czk = "CZK"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chf: return "Swiss Franc"
        case .eur: return "Euro"
        case .usd: return "US Dollar"
        case .gbp: return "British Pound"
        case .sek: return "Swedish Krona"
        case .nok: return "Norwegian Krone"
        case .dkk: return "Danish Krone"
        case .pln: return "Polish Zloty"
        case .czk: return "Czech Koruna"
        }
    }

    var symbol: String {
        switch self {
        case .chf: return "CHF"
        case .eur: return "€"
        case .usd: return "$"
        case .gbp: return "£"
        case .sek: return "kr"
        case .nok: return "kr"
        case .dkk: return "kr"
        case .pln: return "zł"
        case .czk: return "Kč"
        }
    }

    /// The default currency for new price entries.
    static var defaultCurrency: Currency {
        get {
            if let saved = UserDefaults.standard.string(forKey: "defaultCurrency"),
               let currency = Currency(rawValue: saved) {
                return currency
            }
            return .chf
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "defaultCurrency")
        }
    }
}
