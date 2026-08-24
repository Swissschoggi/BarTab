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
                                // Rank
                                Text("#\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(index < 3 ? .barTabAccent : .barTabSecondary)
                                    .frame(width: 32, alignment: .leading)

                                // Level icon
                                Image(systemName: entry.level.icon)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.barTabAccent.opacity(index < 3 ? 1.0 : 0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                // Username + level
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

                                // Contribution count
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
        // Build from all users in the system
        // For now, use local data — in production, fetch from a public view
        var entries: [LeaderboardEntry] = []

        // Count contributions per user
        var userContributions: [String: (username: String, count: Int)] = [:]

        for price in barRepository.prices {
            let userId = price.reportedBy
            let current = userContributions[userId] ?? (username: String(userId.prefix(8)), count: 0)
            userContributions[userId] = (current.username, current.count + 1)
        }

        for bar in barRepository.bars {
            let userId = bar.createdBy
            let current = userContributions[userId] ?? (username: String(userId.prefix(8)), count: 0)
            userContributions[userId] = (current.username, current.count + 1)
        }

        for (userId, data) in userContributions {
            let level = UserLevel.current(for: data.count)
            entries.append(LeaderboardEntry(
                id: userId,
                username: data.username,
                contributions: data.count,
                level: level
            ))
        }

        return entries.sorted { $0.contributions > $1.contributions }
    }
}

private struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let contributions: Int
    let level: UserLevel
}
