import SwiftUI

@main
struct BarTabApp: App {

    @StateObject private var barRepository = BarRepository()
    @StateObject private var userSession = UserSession()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var toastCenter = ToastCenter()

    init() {
        LanguageManager.shared.applyOnLaunch()
        Task {
            await ExchangeRateService.shared.fetchRates()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(languageManager)
                .environmentObject(toastCenter)
                .environment(\.locale, languageManager.currentLocale)
                .barTabToast()
        }
    }
}
