import Foundation
import UserNotifications

enum ReportNotificationService {

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
}