import SwiftUI

struct ActivityFeedView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var items: [ActivityItem] = []
    @State private var isLoading = true
    @State private var userCache: [UUID: String] = [:]

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

                        Text("Follow friends to see their price reports and ratings here.")
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
    }

    private func activityRow(_ item: ActivityItem) -> some View {
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
                }

                Text(item.timestamp.relativeDescription)
                    .font(.caption2)
                    .foregroundColor(.barTabSecondary)
            }

            Spacer()
        }
        .padding(12)
        .barTabCard()
    }

    private func loadFeed() async {
        guard let user = userSession.currentUser else { return }
        do {
            let following = try await SupabaseClient.shared.fetchFollowing()
            items = try await SupabaseClient.shared.fetchActivityFeed(followingIDs: following)

            // Pre-fetch usernames
            for item in items {
                if userCache[item.userID] == nil {
                     if let profile = try? await SupabaseClient.shared.fetchProfile(userID: item.userID) {
                        userCache[item.userID] = profile.display_name ?? "User"
                    }
                }
            }
        } catch {
            print("Failed to load activity feed: \(error)")
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
