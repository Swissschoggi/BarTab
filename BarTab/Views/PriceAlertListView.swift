import SwiftUI

struct PriceAlertListView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var alerts: [PriceAlert] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if alerts.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 44))
                                .foregroundColor(.barTabPrimary)

                            Text("No alerts")
                                .font(.headline)

                            Text("Set a price alert on any drink to be notified when the price changes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(alerts) { alert in
                            alertRow(alert)
                        }
                        .onDelete(perform: delete)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Price Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlerts()
        }
    }

    private func alertRow(_ alert: PriceAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundColor(.barTabAccent)
                .frame(width: 32, height: 32)
                .background(Color.barTabAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.drink)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(alert.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let target = alert.targetPrice {
                Text("\(Currency.defaultCurrency.symbol)\(target, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.barTabAccent)
            } else {
                Text("Any price")
                    .font(.caption)
                    .foregroundColor(.barTabSecondary)
            }
        }
    }

    private func loadAlerts() async {
        do {
            alerts = try await SupabaseClient.shared.fetchPriceAlerts()
        } catch {
            print("Failed to load price alerts: \(error)")
        }
        isLoading = false
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { alerts[$0] }
        alerts.remove(atOffsets: offsets)
        for alert in toDelete {
            Task {
                try? await SupabaseClient.shared.deletePriceAlert(alert.id)
            }
        }
    }
}
