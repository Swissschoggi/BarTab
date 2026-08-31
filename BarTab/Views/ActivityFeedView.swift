import SwiftUI

struct ActivityFeedView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var items: [ActivityItem] = []
    @State private var isLoading = true
    @State private var userCache: [UUID: String] = [:]
    @State private var selectedBar: Bar?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BarTabScreenHeader(
                    title: "Activity",
                    subtitle: "See what your friends are drinking."
                )

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if items.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 44))
                            .foregroundColor(.barTabPrimary)

                        Text("No activity yet")
                            .font(.headline)

                        Text("Accept follow requests to see their price reports and ratings here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()
                } else {
                    ForEach(items) { item in
                        activityRow(item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadFeed()
        }
        .task {
            await loadFeed()
        }
        .sheet(item: $selectedBar) { bar in
            NavigationView {
                BarView(bar: bar, allowsDismissal: true)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func activityRow(_ item: ActivityItem) -> some View {
        Button {
            if let barID = item.barID, let bar = barRepository.getBar(id: barID) {
                selectedBar = bar
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.barTabPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: item.icon)
                            .font(.caption)
                            .foregroundColor(.barTabPrimary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(username(for: item.userID))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(item.actionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    switch item.kind {
                    case .priceReport(let barName, let drink, let amount, let currency):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Currency(rawValue: currency)?.symbol ?? currency)\(amount.formattedAmount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.barTabAccent)
                        }

                    case .barRating(let barName, let ambience):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.caption)
                                .fontWeight(.medium)
                            if let ambience {
                                Text("·")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ambience)
                                    .font(.caption)
                                    .foregroundColor(.barTabSecondary)
                            }
                        }

                    case .drinkRating(let barName, let drink, let quality):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(drink) · \(quality)/5")
                                .font(.caption)
                                .foregroundColor(.barTabSecondary)
                        }

                    case .barCreated(let barName):
                        Text(barName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Text(item.timestamp.relativeDescription)
                        .font(.caption2)
                        .foregroundColor(.barTabSecondary)
                }

                Spacer()

                if item.barID != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.barTabSecondary)
                        .padding(.top, 4)
                }
            }
            .padding(12)
            .barTabCard()
        }
        .buttonStyle(.plain)
    }

    private func loadFeed() async {
        guard let user = userSession.currentUser else { return }
        do {
            let following = try await SupabaseClient.shared.fetchFollowing()
            items = try await SupabaseClient.shared.fetchActivityFeed(followingIDs: following)

            // Batch-fetch all unique usernames   non-fatal if it fails
            let userIDs = Set(items.map(\.userID))
            if let names = try? await SupabaseClient.shared.fetchProfileNamesByIDs(Array(userIDs)) {
                userCache = names
            }
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func username(for userID: UUID) -> String {
        userCache[userID] ?? "Someone"
    }
}

// MARK: - ActivityItem helpers

// icon and actionText are now computed properties on ActivityItem itself

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
