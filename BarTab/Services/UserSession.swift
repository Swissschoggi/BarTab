import Foundation
import Combine
import AuthenticationServices

final class UserSession: ObservableObject {

    @Published private(set) var currentUser: User?

    private let keychain = KeychainService(
        service: "com.bartab.session"
    )
    private let accountStore = AccountStore()
    private let guestUser = User.mockUser

    private var appleUsers: [String: User] = [:]

    init() {
        restoreSession()

        if currentUser == nil {
            currentUser = guestUser
        }
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    func signIn(
        username: String,
        password: String
    ) throws {

        let user = try accountStore.signIn(
            username: username,
            password: password
        )

        currentUser = user
        persistSession()
    }

    func signUp(
        username: String,
        password: String
    ) throws {

        let user = try accountStore.signUp(
            username: username,
            password: password
        )

        currentUser = user
        persistSession()
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        rawNonce: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {

        guard let token = credential.identityToken else {
            completion(
                .failure(
                    AppleIDTokenValidator
                        .ValidationError
                        .invalidToken
                )
            )
            return
        }

        AppleIDTokenValidator.validate(
            token,
            nonce: rawNonce
        ) { [weak self] result in

            DispatchQueue.main.async {

                guard let self = self else {
                    return
                }

                switch result {

                case .failure(let error):
                    completion(.failure(error))

                case .success:

                    let name = [
                        credential.fullName?.givenName,
                        credential.fullName?.familyName
                    ]
                    .compactMap { $0 }
                    .joined(separator: " ")

                    let user: User

                    if let existing =
                        self.appleUsers[credential.user] {
                        user = existing
                    } else {
                        user = User(
                            id: UUID(),
                            username: name.isEmpty
                                ? "Apple User"
                                : name,
                            createdAt: Date()
                        )
                        self.appleUsers[credential.user] = user
                    }

                    self.currentUser = user
                    self.persistSession()
                    completion(.success(user))
                }
            }
        }
    }

    func logout() {
        currentUser = nil
        keychain.delete(account: "current")
    }

    private struct SessionState: Codable {
        var currentUser: User?
        var appleUsers: [String: User]
    }

    private func restoreSession() {

        guard let data = keychain.read(account: "current"),
              let state = try? JSONDecoder().decode(
                  SessionState.self,
                  from: data
              ) else {
            return
        }

        appleUsers = state.appleUsers
        currentUser = state.currentUser
    }

    private func persistSession() {

        let state = SessionState(
            currentUser:
                currentUser?.id == guestUser.id
                ? nil
                : currentUser,
            appleUsers: appleUsers
        )

        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        keychain.write(data, account: "current")
    }
}