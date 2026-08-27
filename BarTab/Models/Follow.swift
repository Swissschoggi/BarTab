import Foundation

struct Follow: Identifiable, Codable {
    let followerID: UUID
    let followingID: UUID
    let createdAt: Date

    var id: String { "\(followerID)-\(followingID)" }

    enum CodingKeys: String, CodingKey {
        case followerID  = "follower_id"
        case followingID = "following_id"
        case createdAt   = "created_at"
    }
}
