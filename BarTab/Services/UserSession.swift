import Foundation
import Combine
import AuthenticationServices

@MainActor
final class UserSession: ObservableObject {

    @Published private(set) var currentUser: User?

    private let authService = SupabaseAuthService()
    private let guestUser = User.mockUser

    init() {

        if let session = authService.restoreSession() {
            currentUser = makeUser(from: session)

            Task {
                await refreshAdminStatus(from: session)
            }
        }

        if currentUser == nil {
            currentUser = guestUser
        }
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    func signIn(
        email: String,
        password: String
    ) async throws {

        let session = try await authService.signIn(
            email: email,
            password: password
        )

        let user = await makeUserWithAdminCheck(
            from: session
        )

        currentUser = user
        authService.saveSession(session)
    }

    func signUp(
        email: String,
        password: String
    ) async throws {

        let session = try await authService.signUp(
            email: email,
            password: password
        )

        let user = await makeUserWithAdminCheck(
            from: session
        )

        currentUser = user
        authService.saveSession(session)
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        rawNonce: String
    ) async throws {

        guard let tokenData = credential.identityToken,
              let token = String(
                  data: tokenData,
                  encoding: .utf8
              ) else {
            throw SupabaseAuthService.AuthError.invalidAppleToken
        }

        let session = try await authService.signInWithApple(
            idToken: token,
            rawNonce: rawNonce
        )

        let user = await makeUserWithAdminCheck(
            from: session
        )

        currentUser = user
        authService.saveSession(session)
    }

    func logout() {

        let accessToken = authService
            .restoreSession()?
            .tokens
            .accessToken

        authService.clearSession()
        currentUser = nil

        if let accessToken = accessToken {
            Task {
                try? await authService.logout(
                    accessToken: accessToken
                )
            }
        }
    }

    // MARK: - Helpers

    private func makeUser(
        from session: SupabaseAuthService.AuthSession
    ) -> User {

        User(
            id: session.user.id,
            username: session.user.username,
            createdAt: session.user.createdAt,
            isAdmin: false
        )
    }

    private func refreshAdminStatus(
        from session: SupabaseAuthService.AuthSession
    ) async {

        let isAdmin = await authService.fetchIsAdmin(
            userID: session.user.id,
            accessToken: session.tokens.accessToken
        )

        guard let user = currentUser,
              user.id == session.user.id,
              user.isAdmin != isAdmin else {
            return
        }

        currentUser = User(
            id: user.id,
            username: user.username,
            createdAt: user.createdAt,
            isAdmin: isAdmin
        )
    }

    private func makeUserWithAdminCheck(
        from session: SupabaseAuthService.AuthSession
    ) async -> User {

        let isAdmin = await authService.fetchIsAdmin(
            userID: session.user.id,
            accessToken: session.tokens.accessToken
        )

        return User(
            id: session.user.id,
            username: session.user.username,
            createdAt: session.user.createdAt,
            isAdmin: isAdmin
        )
    }
}