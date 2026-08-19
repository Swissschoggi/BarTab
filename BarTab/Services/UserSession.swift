import Foundation
import Combine

final class UserSession: ObservableObject {

    @Published private(set) var currentUser: User?

    private var appleUsers: [String: User] = [:]

    init() {
        currentUser = User.mockUser
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    func login(username: String) {
        let user = User(
            id: UUID(),
            username: username,
            createdAt: Date()
        )

        currentUser = user
    }

    func login(
        appleUserID: String,
        username: String
    ) {

        if let existing = appleUsers[appleUserID] {
            currentUser = existing
            return
        }

        let user = User(
            id: UUID(),
            username: username,
            createdAt: Date()
        )

        appleUsers[appleUserID] = user
        currentUser = user
    }

    func logout() {
        currentUser = nil
    }
}
