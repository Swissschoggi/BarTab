import SwiftUI
import CoreLocation

/// Public leaderboard showing usernames and levels only.
/// No bars, locations, or drink history   just contribution levels.
struct LeaderboardView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var locationService: LocationService

    private enum Scope: String, CaseIterable {
        case global = "Global"
        case local = "Local"
    }

    @State private var scope: Scope = .global
    @State private var displayNameCache: [UUID: String] = [:]
    @State private var avatarCache: [UUID: String] = [:]

    /// Bars within the "local" radius of the user's current location.
    private var localBarIDs: Set<UUID> {
        guard let location = locationService.location else { return [] }
        let radius: CLLocationDistance = 10_000
        return Set(barRepository.bars
            .filter { DistanceService.distance(from: location, to: $0) <= radius }
            .map(\.id))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(String(localized: "Scope"), selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: BartapSpacing.md) {

                        if leaderboardEntries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.3.sequence")
                                    .font(.BartapDisplay)
                                    .foregroundColor(.BartapSecondary)

                                Text(scope == .local ? String(localized: "No contributors nearby yet") : String(localized: "No contributors yet"))
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapSecondary)

                                Text(String(localized: "Be the first to add drinks and bars!"))
                                    .font(.BartapSmall)
                                    .foregroundColor(.BartapSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, BartapSpacing.xxl)
                        } else {
                            ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                                HStack(spacing: 12) {
                                    Text("#\(index + 1)")
                                        .font(.BartapBody)
                                        .fontWeight(.bold)
                                        .foregroundColor(index < 3 ? .BartapAccent : .BartapSecondary)
                                        .frame(width: 32, alignment: .leading)

                                    if let userID = UUID(uuidString: entry.id) {
                                        UserAvatarView(urlString: avatarCache[userID], displayName: entry.username, size: 36)
                                    } else {
                                        Image(systemName: entry.level.icon)
                                            .font(.BartapBody)
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color.BartapAccent.opacity(index < 3 ? 1.0 : 0.7))
                                            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.username)
                                            .font(.BartapBody)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.BartapText)

                                        Text(entry.level.name)
                                            .font(.BartapTiny)
                                            .foregroundColor(.BartapSecondary)
                                    }

                                    Spacer()

                                    Text("\(entry.contributions)")
                                        .font(.BartapSmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.BartapPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.BartapPrimary.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, BartapSpacing.sm)

                                if index < leaderboardEntries.count - 1 {
                                    Divider()
                                        .foregroundColor(.BartapCardBorder)
                                        .padding(.leading, BartapSpacing.md)
                                }
                            }
                        }
                    }
                    .padding(.top, BartapSpacing.xs)
                }
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Leaderboard"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadDisplayNames()
        }
    }

    private func loadDisplayNames() async {
        let allUserIDs = Set(leaderboardEntries.compactMap { UUID(uuidString: $0.id) })
        for userID in allUserIDs {
            if displayNameCache[userID] == nil,
               let profile = try? await SupabaseClient.shared.fetchProfile(userID: userID) {
                displayNameCache[userID] = profile.display_name
                if let url = profile.avatar_url {
                    avatarCache[userID] = url
                }
            }
        }
    }

    private var leaderboardEntries: [LeaderboardEntry] {
        var contributionsByUser: [UUID: Int] = [:]

        let relevantBarIDs: Set<UUID> = (scope == .local) ? localBarIDs : Set(barRepository.bars.map(\.id))

        for price in barRepository.prices where relevantBarIDs.contains(price.barID) {
            contributionsByUser[price.reportedBy, default: 0] += 1
        }
        for bar in barRepository.bars where relevantBarIDs.contains(bar.id) {
            contributionsByUser[bar.createdBy, default: 0] += 1
        }

        let isCurrentUser: (UUID) -> Bool = { id in
            guard let user = userSession.currentUser else { return false }
            return id == user.id
        }

        return contributionsByUser.map { userId, count in
            let isSelf = isCurrentUser(userId)
            let name: String = {
                if isSelf {
                    return userSession.currentUser?.username ?? String(localized: "You")
                }
                if let cached = displayNameCache[userId] {
                    return cached
                }
                return String(localized: "Contributor")
            }()
            return LeaderboardEntry(
                id: userId.uuidString,
                username: name,
                contributions: count,
                level: UserLevel.current(for: count)
            )
        }
        .sorted { $0.contributions > $1.contributions }
    }
}

private struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let contributions: Int
    let level: UserLevel
}
