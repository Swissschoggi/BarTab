import Foundation

struct User: Identifiable {
    let id: UUID
    let username: String
    let createdAt: Date

    static let mockUser = User(
        id: UUID(),
        username: "Test User",
        createdAt: Date()
    )
}
