import Foundation
import UserNotifications
import Combine
import UIKit

final class PushNotificationService: ObservableObject {

    static let shared = PushNotificationService()

    @Published private(set) var deviceToken: String?
    @Published private(set) var isAuthorized = false

    private init() {}

    func configure() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        requestAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        UserDefaults.standard.set(tokenString, forKey: "apnsDeviceToken")
        Task { await sendTokenToSupabase(tokenString) }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    private func sendTokenToSupabase(_ token: String) async {
        guard let userID = SupabaseClient.shared.currentUserID else { return }
        do {
            try await SupabaseClient.shared.updateDeviceToken(userID: userID, token: token)
        } catch {
            print("Failed to send device token to Supabase: \(error)")
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deep_link"] as? String,
           let url = URL(string: deepLink) {
            Task { @MainActor in
                DeepLinkRouter.shared.destination = DeepLinkRouter.parse(url: url)
            }
        }
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        PushNotificationService.shared.handleNotificationResponse(response)
        completionHandler()
    }
}