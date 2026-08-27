import Foundation

struct Follow: Codable {
    let followerID: UUID?
    let followingID: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case followerID  = "follower_id"
        case followingID = "following_id"
        case createdAt   = "created_at"
    }
}
