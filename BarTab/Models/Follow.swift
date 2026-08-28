import Foundation

struct Follow: Codable {
    let followerID: UUID?
    let followingID: UUID
    let createdAt: Date?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case followerID  = "follower_id"
        case followingID = "following_id"
        case createdAt   = "created_at"
        case status
    }
}
