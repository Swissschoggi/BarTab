import SwiftUI

/// Public leaderboard showing usernames and levels only.
/// No bars, locations, or drink history — just contribution levels.
struct LeaderboardView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if leaderboardEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.sequence")
                                .font(.largeTitle)
                                .foregroundColor(.barTabSecondary)

                            Text("No contributors yet")
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

                                Image(systemName: entry.level.icon)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.barTabAccent.opacity(index < 3 ? 1.0 : 0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var leaderboardEntries: [LeaderboardEntry] {
        var contributionsByUser: [UUID: Int] = [:]

        for price in barRepository.prices {
            contributionsByUser[price.reportedBy, default: 0] += 1
        }
        for bar in barRepository.bars {
            contributionsByUser[bar.createdBy, default: 0] += 1
        }

        let isCurrentUser: (UUID) -> Bool = { id in
            guard let user = userSession.currentUser else { return false }
            return id == user.id
        }

        return contributionsByUser.map { userId, count in
            LeaderboardEntry(
                id: userId.uuidString,
                username: isCurrentUser(userId)
                    ? (userSession.currentUser?.username ?? "You")
                    : "User \(userId.uuidString.prefix(6))",
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
