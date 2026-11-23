import Foundation
import Combine
import AuthenticationServices
import UIKit

@MainActor
final class UserSession: ObservableObject {

    @Published private(set) var currentUser: User?

    /// The signed-in user's drink tastes (saved during onboarding).
    /// The activity feed ranks matching items first and Discover marks
    /// bars that serve these drinks.
    @Published private(set) var drinkInterests: Set<Drink> = []

    private let authService = SupabaseAuthService()

    private static let interestsDefaultsKey = "drinkInterests"

    init() {

        guard let session = authService.restoreSession() else {
            // Signed out: don't hydrate interests from a previous
            // account that used this device.
            UserDefaults.standard.removeObject(forKey: Self.interestsDefaultsKey)
            return
        }

        // Seed from the local cache so Discover/Activity can personalize
        // before (or without) a backend sync.
        if let saved = UserDefaults.standard.stringArray(forKey: Self.interestsDefaultsKey) {
            drinkInterests = Set(saved.compactMap(Drink.init(rawValue:)))
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

        await setCurrentUser(from: session)
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

        await setCurrentUser(from: session)
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

        await setCurrentUser(from: session)
        authService.saveSession(session)
    }

    /// Completes the Google OAuth flow started by the login screen.
    func signInWithGoogle(
        callbackURL: URL
    ) async throws {

        let session = try await authService.handleGoogleCallback(
            callbackURL
        )

        await setCurrentUser(from: session)
        authService.saveSession(session)
    }

    func logout() async {

        let session = authService.restoreSession()
        let accessToken = session?.tokens.accessToken

        // Stop sharing and remove the remote row while the old access
        // token is still valid. Doing this after `clearSession()` would
        // leave the row visible to friends until it goes stale.
        await LiveLocationService.shared.stopSharingAndClearRemote()

        authService.clearSession()
        currentUser = nil
        drinkInterests = []
        UserDefaults.standard.removeObject(forKey: Self.interestsDefaultsKey)

        if let accessToken {
            Task {
                try? await authService.logout(
                    accessToken: accessToken
                )
            }
        }
    }

    /// Permanently deletes the signed-in user's account and all their data.
    func deleteAccount() async throws {
        // Ensure a valid (refreshed if needed) session so the delete call
        // is authenticated.
        guard await authService.validSession() != nil else {
            throw SupabaseAuthService.AuthError.invalidResponse
        }

        // Remove the live-location row first; account deletion would
        // cascade it, but clearing it explicitly avoids a stale marker
        // if the Edge Function is briefly unavailable.
        await LiveLocationService.shared.stopSharingAndClearRemote()

        try await SupabaseClient.shared.deleteAccount()

        authService.clearSession()
        currentUser = nil
        drinkInterests = []
        UserDefaults.standard.removeObject(forKey: Self.interestsDefaultsKey)
    }

    /// Completes a password-reset deep link and updates the in-memory
    /// session so the user doesn't appear signed out until relaunch.
    func handlePasswordReset(url: URL) async -> Bool {
        let success = await SupabaseAuthService()
            .handleResetPasswordCallback(url)

        guard success,
              let session = authService.restoreSession() else {
            return success
        }

        await setCurrentUser(from: session)
        return true
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

        // Refresh the session if needed so the upload is authenticated
        // with a valid token (RLS on storage rejects anon uploads).
        guard await authService.validSession() != nil else {
            return
        }

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

        await setCurrentUser(from: freshSession)
    }

    /// Refreshes `drinkInterests` from the profiles table. Called after
    /// sign-in/restore and whenever onboarding saves new picks.
    func refreshDrinkInterests(userID: UUID? = nil) async {
        guard let userID = userID ?? currentUser?.id else { return }
        if let interests = try? await SupabaseClient.shared.fetchDrinkInterests(userID: userID) {
            // A logout or account switch may have happened while the
            // request was in flight; never apply another account's data.
            guard currentUser?.id == userID else { return }
            drinkInterests = Set(interests)
            UserDefaults.standard.set(interests.map(\.rawValue), forKey: Self.interestsDefaultsKey)
        }
    }

    /// Optimistically applies locally chosen interests (onboarding) and
    /// caches them on-device so they survive sign-out and cold launches.
    func setDrinkInterests(_ interests: Set<Drink>) {
        drinkInterests = interests
        UserDefaults.standard.set(interests.map(\.rawValue), forKey: Self.interestsDefaultsKey)
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
            ? "Bartap User"
            : session.user.username

        let profile = await authService.fetchProfile(
            userID: session.user.id,
            fallbackUsername: fallbackUsername
        )

        let user = User(
            id: session.user.id,
            username: profile.username,
            createdAt: session.user.createdAt,
            isAdmin: profile.isAdmin,
            avatarURL: profile.avatarURL
        )

        return user
    }

    /// Assigns the profile-backed user and only then refreshes drink
    /// interests, so the guard in `refreshDrinkInterests` sees the new
    /// account instead of racing the assignment.
    private func setCurrentUser(
        from session: SupabaseAuthService.AuthSession
    ) async {
        let user = await makeUserWithAdminCheck(from: session)
        currentUser = user
        await refreshDrinkInterests(userID: user.id)
    }
}
