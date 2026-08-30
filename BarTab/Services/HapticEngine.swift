import UIKit

enum HapticEngine {

    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selectionFeedback = UISelectionFeedbackGenerator()

    static func prepare() {
        impactMedium.prepare()
        impactLight.prepare()
        notification.prepare()
    }

    static func impact() {
        impactMedium.impactOccurred()
    }

    static func lightTap() {
        impactLight.impactOccurred()
    }

    static func selection() {
        selectionFeedback.selectionChanged()
    }

    static func success() {
        notification.notificationOccurred(.success)
    }

    static func error() {
        notification.notificationOccurred(.error)
    }

    static func warning() {
        notification.notificationOccurred(.warning)
    }
}
