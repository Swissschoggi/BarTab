import Foundation

struct Poll: Identifiable, Codable {
    let id: UUID
    let groupID: UUID
    let title: String
    let createdBy: UUID
    let createdAt: Date
    let expiresAt: Date?
    let isClosed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case groupID   = "group_id"
        case title
        case createdBy = "created_by"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isClosed  = "is_closed"
    }

    init(
        id: UUID,
        groupID: UUID,
        title: String,
        createdBy: UUID,
        createdAt: Date,
        expiresAt: Date?,
        isClosed: Bool
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isClosed = isClosed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        groupID = try container.decode(UUID.self, forKey: .groupID)
        title = try container.decode(String.self, forKey: .title)
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        isClosed = try container.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
    }
}

struct PollOption: Identifiable, Codable {
    let id: UUID
    let pollID: UUID
    let barID: UUID?
    let label: String
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case pollID    = "poll_id"
        case barID     = "bar_id"
        case label
        case createdBy = "created_by"
    }
}

struct PollVote: Identifiable, Codable {
    let pollID: UUID
    let optionID: UUID
    let userID: UUID
    let createdAt: Date

    var id: String { "\(pollID)-\(userID)" }

    enum CodingKeys: String, CodingKey {
        case pollID    = "poll_id"
        case optionID  = "option_id"
        case userID    = "user_id"
        case createdAt = "created_at"
    }
}
