import SwiftUI
import UIKit
import Combine
import UserNotifications

@main
struct BarTabApp: App {

    @StateObject private var barRepository = BarRepository()
    @StateObject private var userSession = UserSession()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var locationService = LocationService.shared
    @StateObject private var liveLocationService = LiveLocationService.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    @StateObject private var pushNotificationService = PushNotificationService.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        LanguageManager.shared.applyOnLaunch()
        ReportNotificationService.configure()
        PushNotificationService.shared.configure()
        Self.configureNavigationBars()
        Task {
            await ExchangeRateService.shared.fetchRates()
        }
    }

    /// Custom burgundy back arrow and themed background for every
    /// navigation bar in the app.
    private static func configureNavigationBars() {
        let configuration = UIImage.SymbolConfiguration(
            pointSize: 17,
            weight: .semibold
        )
        let backArrow = UIImage(
            systemName: "arrow.left",
            withConfiguration: configuration
        )?
        .withRenderingMode(.alwaysTemplate)

        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithOpaqueBackground()
        barAppearance.backgroundColor = .barTabBackgroundTint

        let navigationBar = UINavigationBar.appearance()
        navigationBar.backIndicatorImage = backArrow
        navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationBar.tintColor = .barTabPrimaryTint
        navigationBar.standardAppearance = barAppearance
        navigationBar.scrollEdgeAppearance = barAppearance
        navigationBar.compactAppearance = barAppearance

        UIBarButtonItem.appearance().tintColor = .barTabPrimaryTint
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(languageManager)
                .environmentObject(toastCenter)
                .environmentObject(locationService)
                .environmentObject(liveLocationService)
                .environmentObject(deepLinkRouter)
                .environment(\.locale, languageManager.currentLocale)
                .barTabToast(center: toastCenter)
                .task {
                    await barRepository.fetchAllData()
                    await WidgetSnapshotService.refresh(barRepository: barRepository, locationService: locationService)
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
        if url.scheme == SupabaseConfig.oauthCallbackScheme {
            if url.host == "reset-password" || url.host == nil || url.host == "" {
                if url.fragment?.contains("access_token") == true {
                    let success = await SupabaseAuthService().handleResetPasswordCallback(url)
                    if success {
                        await MainActor.run {
                            toastCenter.show(String(localized: "Password updated successfully!"), kind: .success)
                        }
                    }
                    return
                }
            }
            if url.host == "auth/callback" {
                try? await userSession.signInWithGoogle(callbackURL: url)
                return
            }
        }

        guard let destination = parseShareLink(url) else { return }
        await MainActor.run {
            deepLinkRouter.destination = destination
        }
    }

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
            type = url.host
            idString = components.last
        } else {
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

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.didFailToRegisterForRemoteNotificationsWithError(error)
    }
}

/// Routes share deep links to the relevant screen.
@MainActor
final class DeepLinkRouter: ObservableObject {

    static let shared = DeepLinkRouter()

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

    /// Parses a `bartab://bar/<id>` or `bartab://group/<id>` URL.
    static func parse(url: URL) -> Destination? {
        guard url.scheme == SupabaseConfig.oauthCallbackScheme else { return nil }

        let type = url.host
        let idString = url.pathComponents.last
        guard let idString, let id = UUID(uuidString: idString) else { return nil }

        switch type {
        case "bar": return .bar(id)
        case "group": return .group(id)
        default: return nil
        }
    }
}