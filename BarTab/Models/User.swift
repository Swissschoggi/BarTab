import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let username: String
    let createdAt: Date
    let isAdmin: Bool
    let avatarURL: URL?

    init(
        id: UUID,
        username: String,
        createdAt: Date,
        isAdmin: Bool = false,
        avatarURL: URL? = nil
    ) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
        self.isAdmin = isAdmin
        self.avatarURL = avatarURL
    }

    static let mockUser = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "Test User",
        createdAt: Date(),
        isAdmin: true
    )
}
