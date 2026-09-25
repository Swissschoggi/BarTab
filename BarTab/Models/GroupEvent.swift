import Foundation

/// A planned "night out" inside a group. Can hold an ordered
/// crawl of bars (`CrawlStop`) and RSVPs (`EventRSVP`).
struct GroupEvent: Identifiable, Codable {
    let id: UUID
    let groupID: UUID
    let title: String
    let startsAt: Date?
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupID   = "group_id"
        case title
        case startsAt  = "starts_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

/// One stop in an event's shared crawl, ordered by `position`.
struct CrawlStop: Identifiable, Codable {
    let id: UUID
    let eventID: UUID
    let barID: UUID
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case eventID  = "event_id"
        case barID    = "bar_id"
        case position
    }
}

/// A member's "I'm going" for an event.
struct EventRSVP: Codable {
    let eventID: UUID
    let userID: UUID
    let createdAt: Date

    var id: String { "\(eventID)-\(userID)" }

    enum CodingKeys: String, CodingKey {
        case eventID   = "event_id"
        case userID    = "user_id"
        case createdAt = "created_at"
    }
}
