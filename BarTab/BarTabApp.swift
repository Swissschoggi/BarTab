import SwiftUI

@main
struct BarTabApp: App {

    @StateObject private var barRepository = BarRepository()
    @StateObject private var userSession = UserSession()
    @StateObject private var languageManager = LanguageManager.shared

    init() {
        LanguageManager.shared.applyOnLaunch()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.currentLocale)
        }
    }
}
