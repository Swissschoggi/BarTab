import SwiftUI

struct BadgeGridView: View {

    let earnedBadges: [Badge]
    let allBadges: [Badge]
    let streak: Int

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 12)
    ]

    private var unearnedBadges: [Badge] {
        allBadges.filter { badge in
            !earnedBadges.contains { $0.id == badge.id }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Streak card
                if streak > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.barTabTitle)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streak)-day streak")
                                .font(.barTabHeading)
                                .foregroundColor(.barTabText)
                            Text("Keep it going!")
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .barTabCard()
                }

                // Earned badges
                if !earnedBadges.isEmpty {
                    Text("Earned")
                        .font(.barTabHeading)
                        .foregroundColor(.barTabText)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(earnedBadges) { badge in
                            badgeCard(badge, earned: true)
                        }
                    }
                }

                // Unearned badges
                if !unearnedBadges.isEmpty {
                    Text("Locked")
                        .font(.barTabHeading)
                        .foregroundColor(.barTabText)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(unearnedBadges) { badge in
                            badgeCard(badge, earned: false)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func badgeCard(_ badge: Badge, earned: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: badge.icon)
                .font(.barTabTitle)
                .foregroundColor(earned ? .barTabPrimary : .barTabSecondary)
                .frame(width: 44, height: 44)
                .background(
                    earned
                        ? Color.barTabPrimary.opacity(0.1)
                        : Color.gray.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))

            Text(badge.name)
                .font(.barTabSmall)
                .fontWeight(.semibold)
                .foregroundColor(earned ? .barTabText : .barTabSecondary)
                .lineLimit(1)

            Text(badge.description)
                .font(.barTabTiny)
                .foregroundColor(.barTabSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                .fill(earned ? Color.barTabCardFill : Color.barTabCardFill.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                .stroke(earned ? Color.barTabPrimary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(earned ? 1.0 : 0.6)
    }
}
