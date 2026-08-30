import Foundation
import UserNotifications

enum PriceAlertService {

    @MainActor
    static func checkAlerts(
        barRepository: BarRepository
    ) async {
        do {
            let alerts = try await SupabaseClient.shared.fetchPriceAlerts()
            guard !alerts.isEmpty else { return }

            let allPrices = barRepository.prices
            let defaults = UserDefaults.standard
            let key = "notifiedPriceAlerts"

            var notified =
                defaults.dictionary(forKey: key) as? [String: Double] ?? [:]

            for alert in alerts {
                guard alert.isActive else { continue }

                let matchingPrices = allPrices.filter { price in
                    price.barID == alert.barID
                        && price.drink.rawValue == alert.drink
                        && price.size.rawValue == alert.size
                        && (alert.brand == nil || price.brand == alert.brand)
                }

                guard let latestPrice = matchingPrices.max(by: { $0.reportedAt < $1.reportedAt }) else {
                    continue
                }

                let amount = NSDecimalNumber(decimal: latestPrice.amount).doubleValue

                if let target = alert.targetPrice {
                    guard amount <= target else { continue }
                }

                // Only notify once per price; skip if we already told the
                // user about this exact amount for this alert.
                let alertKey = alert.id.uuidString
                if notified[alertKey] == amount { continue }

                let barName = barRepository.getBar(id: alert.barID)?.name ?? "Unknown bar"

                let content = UNMutableNotificationContent()
                content.title = "Price alert"
                content.body = "\(barName) — \(latestPrice.formattedAmount) \(latestPrice.currency)"
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "price-alert-\(alert.id.uuidString)",
                    content: content,
                    trigger: nil
                )

                try await UNUserNotificationCenter.current().add(request)
                notified[alertKey] = amount
            }

            defaults.set(notified, forKey: key)
        } catch {
            // Background check — silently ignore; alerts will be
            // checked again on next foreground transition.
        }
    }
}
