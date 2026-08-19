import Foundation
import Combine

final class UserSession: ObservableObject {

    @Published private(set) var currentUser: User?

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

    func logout() {
        currentUser = nil
    }
}
