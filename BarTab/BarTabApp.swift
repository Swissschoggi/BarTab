import SwiftUI
import Combine

@main
struct BarTabApp: App {

    @StateObject private var barRepository = BarRepository()
    @StateObject private var userSession = UserSession()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var locationService = LocationService.shared

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
                .environmentObject(locationService)
                .environment(\.locale, languageManager.currentLocale)
                .barTabToast(center: toastCenter)
                .task {
                    guard userSession.isLoggedIn else { return }
                    await barRepository.fetchAllData()
                }
                .onReceive(userSession.$currentUser) { user in
                    guard user != nil else { return }
                    Task { await barRepository.fetchAllData() }
                }
                .onOpenURL { url in
                    Task {
                        await handleDeepLink(url)
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willEnterForegroundNotification
                    )
                ) { _ in
                    ReportNotificationService.requestPermission()
                    Task {
                        await PriceAlertService.checkAlerts(barRepository: barRepository)
                    }
                }
        }
    }

    private func handleDeepLink(_ url: URL) async {
        guard url.scheme == SupabaseConfig.oauthCallbackScheme else { return }

        // Password reset callback: bartab://reset-password#access_token=...
        // or bartab://#access_token=... (when redirect_to is just the site URL)
        if url.host == "reset-password" || url.host == nil || url.host == "" {
            if url.fragment?.contains("access_token") == true {
                let success = await SupabaseAuthService().handleResetPasswordCallback(url)
                if success {
                    await MainActor.run {
                        toastCenter.show("Password updated successfully!", kind: .success)
                    }
                }
                return
            }
        }

        // Google OAuth callback: bartab://auth/callback#access_token=...
        if url.host == "auth/callback" {
            try? await userSession.signInWithGoogle(callbackURL: url)
        }
    }
}
