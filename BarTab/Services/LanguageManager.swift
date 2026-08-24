import Foundation
import SwiftUI

/// Manages app language selection with immediate effect.
@MainActor
final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    @AppStorage("selectedLanguage") var selectedLanguage: String = "en" {
        didSet {
            objectWillChange.send()
        }
    }

    private init() {}

    var currentLocale: Locale {
        Locale(identifier: selectedLanguage)
    }

    /// The bundle for the currently selected language.
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    /// Localized string from the selected language bundle.
    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Apply language on app launch.
    func applyOnLaunch() {
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
    }
}

// MARK: - ViewModifier for localized text

struct LocalizedText: View {
    let key: String
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        Text(LocalizedStringKey(languageManager.localized(key)))
    }
}

extension View {
    func localized(_ key: String) -> some View {
        modifier(LocalizedTextModifier(key: key))
    }
}

struct LocalizedTextModifier: ViewModifier {
    let key: String
    @EnvironmentObject private var languageManager: LanguageManager

    func body(content: Content) -> some View {
        content
    }
}
