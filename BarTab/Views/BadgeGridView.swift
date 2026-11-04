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
                            .font(.BartapTitle)
                            .foregroundColor(.BartapWarning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "\(streak)-day streak"))
                                .font(.BartapHeading)
                                .foregroundColor(.BartapText)
                            Text(String(localized: "Keep it going!"))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .BartapCard()
                }

                // Earned badges
                if !earnedBadges.isEmpty {
                    Text(String(localized: "Earned"))
                        .font(.BartapHeading)
                        .foregroundColor(.BartapText)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(earnedBadges) { badge in
                            badgeCard(badge, earned: true)
                        }
                    }
                }

                // Unearned badges
                if !unearnedBadges.isEmpty {
                    Text(String(localized: "Locked"))
                        .font(.BartapHeading)
                        .foregroundColor(.BartapText)

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
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Badges"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func badgeCard(_ badge: Badge, earned: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: badge.icon)
                .font(.BartapTitle)
                .foregroundColor(earned ? .BartapPrimary : .BartapSecondary)
                .frame(width: 44, height: 44)
                .background(
                    earned
                        ? Color.BartapPrimary.opacity(0.1)
                        : Color.gray.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))

            Text(badge.name)
                .font(.BartapSmall)
                .fontWeight(.semibold)
                .foregroundColor(earned ? .BartapText : .BartapSecondary)
                .lineLimit(1)

            Text(badge.description)
                .font(.BartapTiny)
                .foregroundColor(.BartapSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BartapSpacing.sm)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                .fill(earned ? Color.BartapCardFill : Color.BartapCardFill.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                .stroke(earned ? Color.BartapPrimary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .opacity(earned ? 1.0 : 0.6)
    }
}
