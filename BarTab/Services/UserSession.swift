import Foundation
import Combine
import AuthenticationServices
import UIKit

@MainActor
final class UserSession: ObservableObject {

    @Published private(set) var currentUser: User?

    private let authService = SupabaseAuthService()

    init() {

        guard let session = authService.restoreSession() else {
            return
        }

        // Show the cached identity immediately, then refresh it
        // from the profiles table (and the token itself) in the
        // background so username/admin/avatar stay accurate.
        currentUser = makeUser(from: session)

        Task {
            await restoreFreshUser(from: session)
        }
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    // MARK: - Sign in

    func signIn(
        email: String,
        password: String
    ) async throws {

        let session = try await authService.signIn(
            email: email,
            password: password
        )

        currentUser = await makeUserWithAdminCheck(
            from: session
        )
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

        currentUser = await makeUserWithAdminCheck(
            from: session
        )
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

        currentUser = await makeUserWithAdminCheck(
            from: session
        )
        authService.saveSession(session)
    }

    /// Completes the Google OAuth flow started by the login screen.
    func signInWithGoogle(
        callbackURL: URL
    ) async throws {

        let session = try await authService.handleGoogleCallback(
            callbackURL
        )

        currentUser = await makeUserWithAdminCheck(
            from: session
        )
        authService.saveSession(session)
    }

    func logout() {

        let session = authService.restoreSession()
        let accessToken = session?.tokens.accessToken

        if let accessToken {
            Task {
                try? await authService.logout(
                    accessToken: accessToken
                )
            }
        }

        authService.clearSession()
        currentUser = nil
    }

    /// Permanently deletes the signed-in user's account and all their data.
    func deleteAccount() async throws {
        // Ensure a valid (refreshed if needed) session so the delete call
        // is authenticated.
        guard await authService.validSession() != nil else {
            return
        }

        try await SupabaseClient.shared.deleteAccount()

        authService.clearSession()
        currentUser = nil
    }

    // MARK: - Account updates

    func updateUsername(_ newUsername: String) async throws {

        guard let session = await authService.validSession() else {
            return
        }

        try await authService.updateUsername(
            newUsername,
            accessToken: session.tokens.accessToken
        )

        // Also sync the profiles table display_name
        if let userID = currentUser?.id {
            try? await SupabaseClient.shared.updateProfileDisplayName(
                userID: userID,
                displayName: newUsername
            )
        }

        if let user = currentUser {
            currentUser = User(
                id: user.id,
                username: newUsername,
                createdAt: user.createdAt,
                isAdmin: user.isAdmin,
                avatarURL: user.avatarURL
            )
        }
    }

    func updatePassword(_ newPassword: String) async throws {

        guard let session = await authService.validSession() else {
            return
        }

        try await authService.updatePassword(
            newPassword,
            accessToken: session.tokens.accessToken
        )
    }

    /// Uploads a new avatar image and stores its public URL on the
    /// profile.
    func updateAvatar(image: UIImage) async throws {

        guard let user = currentUser else { return }

        guard let jpegData = AvatarService.processedJPEGData(
            from: image
        ) else {
            throw AvatarService.AvatarError.processingFailed
        }

        let url = try await SupabaseClient.shared.uploadAvatar(
            userID: user.id,
            jpegData: jpegData
        )

        try await SupabaseClient.shared.updateProfileAvatarURL(
            userID: user.id,
            avatarURL: url.absoluteString
        )

        currentUser = User(
            id: user.id,
            username: user.username,
            createdAt: user.createdAt,
            isAdmin: user.isAdmin,
            avatarURL: url
        )
    }

    func refreshProfile() async {
        guard let session = await authService.validSession() else {
            return
        }
        await refreshAdminStatus(from: session)
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

    /// Refreshes the stored tokens if they are close to expiry and
    /// rebuilds the current user from the server profile.
    private func restoreFreshUser(
        from session: SupabaseAuthService.AuthSession
    ) async {

        guard let freshSession = await authService.validSession() else {
            // Refresh failed (e.g. revoked); keep the cached user
            // visible but they'll be prompted to sign in again on
            // their next write.
            return
        }

        currentUser = await makeUserWithAdminCheck(
            from: freshSession
        )
    }

    private func refreshAdminStatus(
        from session: SupabaseAuthService.AuthSession
    ) async {

        let profile = await makeUserWithAdminCheck(from: session)

        guard currentUser?.id == profile.id else { return }

        currentUser = profile
    }

    private func makeUserWithAdminCheck(
        from session: SupabaseAuthService.AuthSession
    ) async -> User {

        let fallbackUsername = session.user.username.isEmpty
            ? "BarTab User"
            : session.user.username

        let profile = await authService.fetchProfile(
            userID: session.user.id,
            fallbackUsername: fallbackUsername
        )

        return User(
            id: session.user.id,
            username: profile.username,
            createdAt: session.user.createdAt,
            isAdmin: profile.isAdmin,
            avatarURL: profile.avatarURL
        )
    }
}
