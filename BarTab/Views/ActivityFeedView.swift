import SwiftUI

struct ActivityFeedView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var items: [ActivityItem] = []
    @State private var isLoading = true
    @State private var userCache: [UUID: String] = [:]
    @State private var avatarCache: [UUID: String] = [:]
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
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)

                        Text("No activity yet")
                            .font(.barTabHeading)

                        Text("Accept follow requests to see their price reports and ratings here.")
                            .font(.barTabBody)
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
                UserAvatarView(urlString: avatarCache[item.userID], displayName: username(for: item.userID))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(username(for: item.userID))
                            .font(.barTabBody)
                            .fontWeight(.semibold)

                        Text(item.actionText)
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                    }

                    switch item.kind {
                    case .priceReport(let barName, _, let amount, let currency):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.barTabSmall)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.barTabSmall)
                                .foregroundColor(.secondary)
                            Text("\(Currency(rawValue: currency)?.symbol ?? currency)\(amount.formattedAmount)")
                                .font(.barTabSmall)
                                .fontWeight(.bold)
                                .foregroundColor(.barTabAccent)
                        }

                    case .barRating(let barName, let ambience):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.barTabSmall)
                                .fontWeight(.medium)
                            if let ambience {
                                Text("·")
                                    .font(.barTabSmall)
                                    .foregroundColor(.secondary)
                                Text(ambience)
                                    .font(.barTabSmall)
                                    .foregroundColor(.barTabSecondary)
                            }
                        }

                    case .drinkRating(let barName, let drink, let quality):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.barTabSmall)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.barTabSmall)
                                .foregroundColor(.secondary)
                            Text("\(drink) · \(quality)/5")
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)
                        }

                    case .barCreated(let barName):
                        Text(barName)
                            .font(.barTabSmall)
                            .fontWeight(.medium)
                    }

                    Text(item.timestamp.relativeDescription)
                        .font(.barTabTiny)
                        .foregroundColor(.barTabSecondary)
                }

                Spacer()

                if item.barID != nil {
                    Image(systemName: "chevron.right")
                        .font(.barTabTiny)
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

            // Batch-fetch all unique usernames + avatar URLs
            let userIDs = Set(items.map(\.userID))
            if let profiles = try? await SupabaseClient.shared.fetchProfileAvatarsByIDs(Array(userIDs)) {
                for (id, profile) in profiles {
                    userCache[id] = profile.displayName ?? "User"
                    if let url = profile.avatarURL {
                        avatarCache[id] = url
                    }
                }
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
