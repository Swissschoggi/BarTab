import Foundation
import SwiftUI

/// Manages app language selection and forces the correct locale.
@MainActor
final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    @AppStorage("selectedLanguage") var selectedLanguage: String = "en" {
        didSet {
            applyLanguage()
            objectWillChange.send()
        }
    }

    private init() {
        applyLanguage()
    }

    var currentLocale: Locale {
        Locale(identifier: selectedLanguage)
    }

    /// Apply the selected language to the app's locale.
    private func applyLanguage() {
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    /// The bundle for the currently selected language.
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
}
