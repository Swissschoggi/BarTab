import Foundation

struct BarGroup: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct GroupMember: Identifiable, Codable {
    let groupID: UUID
    let userID: UUID
    let role: String
    let joinedAt: Date

    var id: String { "\(groupID)-\(userID)" }
    var isAdmin: Bool { role == "admin" }

    enum CodingKeys: String, CodingKey {
        case groupID  = "group_id"
        case userID   = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}
