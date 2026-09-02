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
        NavigationView {
            VStack(spacing: 0) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        if leaderboardEntries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.3.sequence")
                                    .font(.largeTitle)
                                    .foregroundColor(.barTabSecondary)

                                Text(scope == .local ? "No contributors nearby yet" : "No contributors yet")
                                    .font(.subheadline)
                                    .foregroundColor(.barTabSecondary)

                                Text("Be the first to add drinks and bars!")
                                    .font(.caption)
                                    .foregroundColor(.barTabSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                                HStack(spacing: 12) {
                                    Text("#\(index + 1)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(index < 3 ? .barTabAccent : .barTabSecondary)
                                        .frame(width: 32, alignment: .leading)

                                    if let userID = UUID(uuidString: entry.id) {
                                        UserAvatarView(urlString: avatarCache[userID], displayName: entry.username, size: 36)
                                    } else {
                                        Image(systemName: entry.level.icon)
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color.barTabAccent.opacity(index < 3 ? 1.0 : 0.7))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.username)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.barTabText)

                                        Text(entry.level.name)
                                            .font(.caption2)
                                            .foregroundColor(.barTabSecondary)
                                    }

                                    Spacer()

                                    Text("\(entry.contributions)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.barTabPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.barTabPrimary.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if index < leaderboardEntries.count - 1 {
                                    Divider()
                                        .foregroundColor(.barTabCardBorder)
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Leaderboard")
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
                    return userSession.currentUser?.username ?? "You"
                }
                if let cached = displayNameCache[userId] {
                    return cached
                }
                return "Contributor"
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
