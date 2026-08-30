import Foundation

final class BadgeService {

    static let shared = BadgeService()

    private let streakKey = "com.bartab.streak"
    private let lastContributionKey = "com.bartab.lastContributionDate"
    private let earnedBadgesKey = "com.bartab.earnedBadges"

    private init() {}

    // MARK: - Streak

    var currentStreak: Int {
        UserDefaults.standard.integer(forKey: streakKey)
    }

    var lastContributionDate: Date? {
        UserDefaults.standard.object(forKey: lastContributionKey) as? Date
    }

    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = lastContributionDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if diff == 0 {
                // Same day, no change
                return
            } else if diff == 1 {
                // Consecutive day
                let newStreak = currentStreak + 1
                UserDefaults.standard.set(newStreak, forKey: streakKey)
            } else {
                // Streak broken
                UserDefaults.standard.set(1, forKey: streakKey)
            }
        } else {
            // First contribution
            UserDefaults.standard.set(1, forKey: streakKey)
        }

        UserDefaults.standard.set(today, forKey: lastContributionKey)
    }

    // MARK: - Badges

    var earnedBadgeIDs: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: earnedBadgesKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: earnedBadgesKey)
        }
    }

    func isEarned(_ badge: Badge) -> Bool {
        earnedBadgeIDs.contains(badge.id)
    }

    /// Checks all badges against current stats and returns any newly earned badges.
    func checkBadges(
        priceCount: Int,
        barCount: Int,
        followCount: Int,
        drinkRatingCount: Int,
        barRatingCount: Int
    ) -> [Badge] {
        var newlyEarned: [Badge] = []
        var earned = earnedBadgeIDs

        let stats: [(Badge, Int)] = [
            // Price milestones
            (Badge.allMilestones[0], priceCount),   // First Pour
            (Badge.allMilestones[1], priceCount),   // Regular
            (Badge.allMilestones[2], priceCount),   // Tastemaker
            (Badge.allMilestones[3], priceCount),   // Price Guru
            // Bar milestones
            (Badge.allMilestones[4], barCount),     // Bar Scout
            (Badge.allMilestones[5], barCount),     // Explorer
            // Social
            (Badge.allMilestones[6], followCount),  // Social Butterfly
            // Ratings
            (Badge.allMilestones[7], drinkRatingCount), // Critic
            (Badge.allMilestones[8], barRatingCount),   // Ambience Expert
        ]

        for (badge, count) in stats {
            if !earned.contains(badge.id) && count >= badge.threshold {
                earned.insert(badge.id)
                newlyEarned.append(badge)
            }
        }

        // Streak badges
        let streak = currentStreak
        for badge in Badge.streakBadges {
            if !earned.contains(badge.id) && streak >= badge.threshold {
                earned.insert(badge.id)
                newlyEarned.append(badge)
            }
        }

        earnedBadgeIDs = earned
        return newlyEarned
    }

    func earnedBadges() -> [Badge] {
        let earned = earnedBadgeIDs
        return (Badge.allMilestones + Badge.streakBadges).filter { earned.contains($0.id) }
    }

    func allBadges() -> [Badge] {
        Badge.allMilestones + Badge.streakBadges
    }
}
