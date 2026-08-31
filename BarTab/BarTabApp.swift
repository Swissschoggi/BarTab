import SwiftUI
import Combine

@main
struct BarTabApp: App {

    @StateObject private var barRepository = BarRepository()
    @StateObject private var userSession = UserSession()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var locationService = LocationService.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter()

    init() {
        LanguageManager.shared.applyOnLaunch()
        ReportNotificationService.configure()
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
                .environmentObject(deepLinkRouter)
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
        // App scheme (bartab://) — OAuth callbacks only.
        if url.scheme == SupabaseConfig.oauthCallbackScheme {

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
                return
            }
        }

        // Share links — both `bartab://bar/<id>` and
        // `https://bartap.info/bar/<id>` (and group equivalents).
        guard let destination = parseShareLink(url) else { return }

        await MainActor.run {
            deepLinkRouter.destination = destination
        }
    }

    /// Parses a bar/group share link from either the app scheme or the
    /// Universal Link host.
    private func parseShareLink(
        _ url: URL
    ) -> DeepLinkRouter.Destination? {

        let isApp = url.scheme == SupabaseConfig.oauthCallbackScheme
        let isWeb = url.scheme == "https" && url.host == DeepLink.host
        guard isApp || isWeb else { return nil }

        let components = url.pathComponents
        let type: String?
        let idString: String?

        if isApp {
            // bartab://bar/<id>
            type = url.host
            idString = components.last
        } else {
            // https://bartap.info/bar/<id>
            guard components.count >= 3 else { return nil }
            type = components[components.count - 2]
            idString = components.last
        }

        guard let idString, let id = UUID(uuidString: idString) else {
            return nil
        }

        switch type {
        case "bar":
            return .bar(id)
        case "group":
            return .group(id)
        default:
            return nil
        }
    }
}

/// Routes share deep links to the relevant screen.
@MainActor
final class DeepLinkRouter: ObservableObject {

    enum Destination: Identifiable, Equatable {
        case bar(UUID)
        case group(UUID)

        var id: String {
            switch self {
            case .bar(let id): return "bar-\(id.uuidString)"
            case .group(let id): return "group-\(id.uuidString)"
            }
        }
    }

    @Published var destination: Destination?
}
