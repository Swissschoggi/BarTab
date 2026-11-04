import SwiftUI

struct ActivityFeedView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var locationService: LocationService

    @State private var items: [ActivityItem] = []
    @State private var isLoading = true
    @State private var userCache: [UUID: String] = [:]
    @State private var avatarCache: [UUID: String] = [:]
    @State private var selectedBar: Bar?
    @State private var refreshError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BartapSpacing.md) {

                BartapScreenHeader(
                    title: String(localized: "Activity"),
                    subtitle: String(localized: "See what your friends are drinking.")
                )

                if let refreshError {
                    Text(refreshError)
                        .font(.BartapSmall)
                        .foregroundColor(.BartapDanger)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    .padding(.vertical, BartapSpacing.xxl)
                } else if items.isEmpty {
                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "person.2.slash")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)

                        Text(String(localized: "No activity yet"))
                            .font(.BartapHeading)

                        Text(String(localized: "Accept follow requests to see their price reports and ratings here."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()
                } else {
                    ForEach(items) { item in
                        activityRow(item)
                    }
                }
            }
            .padding(.horizontal, BartapSpacing.md)
            .padding(.vertical, BartapSpacing.lg)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Activity"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadFeed()
        }
        .task {
            await loadFeed()
        }
        .sheet(item: $selectedBar) { bar in
            NavigationStack {
                BarView(bar: bar, allowsDismissal: true)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
                    .environmentObject(locationService)
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
                            .font(.BartapBody)
                            .fontWeight(.semibold)

                        Text(item.actionText)
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                    }

                    switch item.kind {
                    case .priceReport(let barName, _, let amount, let currency):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.BartapSmall)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.BartapSmall)
                                .foregroundColor(.secondary)
                            Text("\(Currency(rawValue: currency)?.symbol ?? currency)\(amount.formattedAmount)")
                                .font(.BartapSmall)
                                .fontWeight(.bold)
                                .foregroundColor(.BartapAccent)
                        }

                    case .barRating(let barName, let ambience):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.BartapSmall)
                                .fontWeight(.medium)
                            if let ambience {
                                Text("·")
                                    .font(.BartapSmall)
                                    .foregroundColor(.secondary)
                                Text(ambience)
                                    .font(.BartapSmall)
                                    .foregroundColor(.BartapSecondary)
                            }
                        }

                    case .drinkRating(let barName, let drink, let quality):
                        HStack(spacing: 4) {
                            Text(barName)
                                .font(.BartapSmall)
                                .fontWeight(.medium)
                            Text("·")
                                .font(.BartapSmall)
                                .foregroundColor(.secondary)
                            Text("\(drink) · \(quality)/5")
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                        }

                    case .barCreated(let barName):
                        Text(barName)
                            .font(.BartapSmall)
                            .fontWeight(.medium)
                    }

                    Text(item.timestamp.relativeDescription)
                        .font(.BartapTiny)
                        .foregroundColor(.BartapSecondary)
                }

                Spacer()

                if matchesTaste(item) {
                    Text(String(localized: "For you"))
                        .font(.BartapTiny)
                        .fontWeight(.semibold)
                        .foregroundColor(.BartapAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.BartapAccent.opacity(0.15))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }

                if item.barID != nil {
                    Image(systemName: "chevron.right")
                        .font(.BartapTiny)
                        .foregroundColor(.BartapSecondary)
                        .padding(.top, 4)
                }
            }
            .padding(12)
            .BartapCard()
        }
        .buttonStyle(.plain)
    }

    private func loadFeed() async {
        guard let user = userSession.currentUser else { return }
        do {
            let following = try await SupabaseClient.shared.fetchFollowing()
            let fetched = try await SupabaseClient.shared.fetchActivityFeed(followingIDs: following)

            // Personalize: items matching the drink interests saved in
            // onboarding float to the top, recency preserved within each
            // group.
            items = rankedForYou(fetched)

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
            refreshError = nil
        } catch {
            toastCenter.showError(error)
            if !items.isEmpty {
                refreshError = String(localized: "Couldn't refresh. Showing earlier activity.")
            }
        }
        isLoading = false
    }

    // MARK: - Personalization

    private func rankedForYou(_ items: [ActivityItem]) -> [ActivityItem] {
        guard !userSession.drinkInterests.isEmpty else { return items }
        let matching = items.filter(matchesTaste)
        guard matching.count != items.count else { return items }
        let rest = items.filter { !matchesTaste($0) }
        return matching + rest
    }

    /// True when the item involves one of the user's favorite drinks —
    /// either directly (price/drink report) or at a bar that serves one.
    private func matchesTaste(_ item: ActivityItem) -> Bool {
        let interests = userSession.drinkInterests
        guard !interests.isEmpty else { return false }

        switch item.kind {
        case .priceReport(_, let drink, _, _), .drinkRating(_, let drink, _):
            return Drink(rawValue: drink).map(interests.contains) ?? false

        case .barRating, .barCreated:
            guard let barID = item.barID,
                  let bar = barRepository.getBar(id: barID) else { return false }
            return barRepository.getPrices(for: bar).contains {
                interests.contains($0.drink)
            }
        }
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
