import Foundation
import UserNotifications

enum ReportNotificationService {

    private static let delegate = NotificationDelegate()

    /// Must be called once at app launch so notifications are shown even
    /// while the app is in the foreground.
    static func configure() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { _, _ in }
    }

    static func schedule(for report: ContentReport) {

        let content = UNMutableNotificationContent()
        content.title = "New report"
        content.body =
            "\"\(report.targetLabel)\" was flagged "
            + "(\(report.reason.title))."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: report.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current()
            .add(request)
    }

    private final class NotificationDelegate: NSObject,
        UNUserNotificationCenterDelegate {

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler:
                @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound])
        }
    }
}
