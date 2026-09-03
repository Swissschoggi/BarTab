import Foundation

struct Badge: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let threshold: Int
    let kind: Kind

    enum Kind {
        case milestone
        case streak
    }

    static let allMilestones: [Badge] = [
        Badge(
            id: "first_pour",
            name: String(localized: "First Pour"),
            description: String(localized: "Report your first drink price"),
            icon: "drop.fill",
            threshold: 1,
            kind: .milestone
        ),
        Badge(
            id: "regular",
            name: String(localized: "Regular"),
            description: String(localized: "Report 5 drink prices"),
            icon: "clock.fill",
            threshold: 5,
            kind: .milestone
        ),
        Badge(
            id: "tastemaker",
            name: String(localized: "Tastemaker"),
            description: String(localized: "Report 15 drink prices"),
            icon: "star.fill",
            threshold: 15,
            kind: .milestone
        ),
        Badge(
            id: "price_guru",
            name: String(localized: "Price Guru"),
            description: String(localized: "Report 50 drink prices"),
            icon: "dollarsign.circle.fill",
            threshold: 50,
            kind: .milestone
        ),
        Badge(
            id: "bar_scout",
            name: String(localized: "Bar Scout"),
            description: String(localized: "Add 5 bars"),
            icon: "mappin.circle.fill",
            threshold: 5,
            kind: .milestone
        ),
        Badge(
            id: "explorer",
            name: String(localized: "Explorer"),
            description: String(localized: "Add 15 bars"),
            icon: "map.fill",
            threshold: 15,
            kind: .milestone
        ),
        Badge(
            id: "social_butterfly",
            name: String(localized: "Social Butterfly"),
            description: String(localized: "Follow 5 people"),
            icon: "person.2.fill",
            threshold: 5,
            kind: .milestone
        ),
        Badge(
            id: "critic",
            name: String(localized: "Critic"),
            description: String(localized: "Rate 10 drinks"),
            icon: "hand.thumbsup.fill",
            threshold: 10,
            kind: .milestone
        ),
        Badge(
            id: "ambience_expert",
            name: String(localized: "Ambience Expert"),
            description: String(localized: "Rate 10 bars"),
            icon: "star.circle.fill",
            threshold: 10,
            kind: .milestone
        ),
    ]

    static let streakBadges: [Badge] = [
        Badge(
            id: "streak_7",
            name: String(localized: "On Fire"),
            description: String(localized: "7-day contribution streak"),
            icon: "flame.fill",
            threshold: 7,
            kind: .streak
        ),
        Badge(
            id: "streak_30",
            name: String(localized: "Unstoppable"),
            description: String(localized: "30-day contribution streak"),
            icon: "flame.circle.fill",
            threshold: 30,
            kind: .streak
        ),
    ]
}
