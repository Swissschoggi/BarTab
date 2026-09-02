import SwiftUI
import AuthenticationServices

/// Presents the OAuth web sheet for Google sign-in.
final class OAuthPresentationAnchorProvider: NSObject,
    ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

struct LoginView: View {

    enum Mode: String, CaseIterable, Identifiable {
        case signIn
        case createAccount

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signIn:
                return "Sign in"

            case .createAccount:
                return "Create account"
            }
        }
    }

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isGoogleSigningIn = false

    @State private var oauthPresenter = OAuthPresentationAnchorProvider()

    var body: some View {

        NavigationView {

            ScrollView {

                VStack(spacing: 24) {

                    VStack(spacing: 8) {

                        ZStack {
                            Circle()
                                .fill(Color.barTabPrimary)
                                .frame(width: 72, height: 72)

                            Image(systemName: "wineglass.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        Text("Welcome to BarTab")
                            .font(.barTabTitle)
                            .foregroundColor(.barTabText)

                        Text(
                            "Create an account to add and manage drinks."
                        )
                        .font(.barTabBody)
                        .foregroundColor(.barTabSecondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)


                    googleSignInButton

                    SignInWithAppleButton(
                        .signIn
                    ) { request in

                        request.requestedScopes = [
                            .fullName,
                            .email
                        ]

                        let rawNonce =
                            SupabaseAuthService
                            .randomNonceString()

                        currentNonce = rawNonce
                        request.nonce =
                            SupabaseAuthService
                            .sha256(rawNonce)

                    } onCompletion: { result in

                        handleAppleSignIn(result)
                    }
                    .frame(height: 50)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: BarTabRadius.control,
                            style: .continuous
                        )
                    )
                    .signInWithAppleButtonStyle(
                        .whiteOutline
                    )
                    .disabled(isSubmitting || isGoogleSigningIn)


                    HStack(spacing: 12) {

                        VStack { Divider() }

                        Text("or use an email")
                            .font(.barTabSmall)
                            .foregroundColor(.barTabSecondary)

                        VStack { Divider() }
                    }


                    VStack(spacing: 14) {

                        Picker(
                            "Mode",
                            selection: $mode
                        ) {
                            ForEach(Mode.allCases) { option in
                                Text(option.title)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            Text("Email")
                                .font(.barTabCaption)
                                .foregroundColor(.barTabSecondary)

                            TextField(
                                "Your email",
                                text: $email
                            )
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(BarTabFieldStyle())
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            Text("Password")
                                .font(.barTabCaption)
                                .foregroundColor(.barTabSecondary)

                            HStack {
                                if showPassword {
                                    TextField(
                                        mode == .createAccount
                                        ? "At least 8 characters"
                                        : "Your password",
                                        text: $password
                                    )
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                } else {
                                    SecureField(
                                        mode == .createAccount
                                        ? "At least 8 characters"
                                        : "Your password",
                                        text: $password
                                    )
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.barTabSecondary)
                                        .font(.barTabCaption)
                                }
                            }
                            .font(.barTabBody)
                            .barTabFieldSurface()
                        }

                        if mode == .signIn {
                            HStack {
                                Spacer()
                                NavigationLink {
                                    ForgotPasswordView()
                                } label: {
                                    Text("Forgot Password?")
                                        .font(.barTabBody)
                                        .foregroundColor(.barTabAccent)
                                }
                            }
                        }

                        if mode == .createAccount {

                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {

                                Text("Confirm password")
                                    .font(.barTabCaption)
                                    .foregroundColor(.barTabSecondary)

                                HStack {
                                    if showConfirmPassword {
                                        TextField(
                                            "Repeat your password",
                                            text: $confirmPassword
                                        )
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                    } else {
                                        SecureField(
                                            "Repeat your password",
                                            text: $confirmPassword
                                        )
                                    }

                                    Button {
                                        showConfirmPassword.toggle()
                                    } label: {
                                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.barTabSecondary)
                                            .font(.barTabCaption)
                                    }
                                }
                                .font(.barTabBody)
                                .barTabFieldSurface()
                            }
                        }
                    }


                    Button {
                        submit()
                    } label: {

                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(submitTitle)
                        }
                        .barTabPrimaryButton()
                    }
                    .disabled(!canSubmit || isSubmitting || isGoogleSigningIn)


                    if let errorMessage {

                        Label {
                            Text(errorMessage)
                                .font(.barTabTiny)
                                .multilineTextAlignment(.leading)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                        .foregroundColor(.barTabDanger)
                        .padding(BarTabSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.barTabDanger.opacity(0.08),
                            in: RoundedRectangle(
                                cornerRadius: BarTabRadius.control,
                                style: .continuous
                            )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }


                    Text(
                        "Your account lives on BarTab's server. "
                    )
                    .font(.barTabSmall)
                    .foregroundColor(.barTabSecondary)
                    .multilineTextAlignment(.center)

                    Spacer(minLength: 16)
                }
                .padding(24)
            }
            .background(Color.barTabBackground)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
        .animation(.easeOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - Google sign-in

    private var googleSignInButton: some View {

        Button {
            startGoogleSignIn()
        } label: {

            HStack(spacing: 10) {

                if isGoogleSigningIn {
                    ProgressView()
                } else {
                    Text("G")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(
                            Color(red: 0.26, green: 0.52, blue: 0.96)
                        )
                }

                Text(isGoogleSigningIn ? "Connecting…" : "Continue with Google")
                    .font(.barTabBodySemibold)
                    .foregroundColor(.barTabText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: BarTabRadius.control,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: BarTabRadius.control,
                    style: .continuous
                )
                .stroke(Color.barTabCardBorder, lineWidth: 0.5)
            )
        }
        .disabled(isSubmitting || isGoogleSigningIn)
    }

    private func startGoogleSignIn() {

        guard let authorizeURL = SupabaseAuthService.googleAuthorizeURL() else {
            errorMessage = "Google sign-in isn't configured."
            return
        }

        errorMessage = nil
        isGoogleSigningIn = true

        let session = ASWebAuthenticationSession(
            url: authorizeURL,
            callbackURLScheme: SupabaseConfig.oauthCallbackScheme
        ) { callbackURL, error in

            if let callbackURL {
                Task {
                    do {
                        try await userSession.signInWithGoogle(
                            callbackURL: callbackURL
                        )
                        isGoogleSigningIn = false
                        toastCenter.show(
                            "Signed in with Google",
                            kind: .success
                        )
                        dismiss()
                    } catch {
                        isGoogleSigningIn = false
                        if (error as? SupabaseAuthService.AuthError) != nil {
                            errorMessage = FriendlyError.message(for: error)
                        } else {
                            errorMessage = "Google sign-in failed. Please try again."
                        }
                    }
                }
                return
            }

            isGoogleSigningIn = false

            guard let error else { return }

            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                return
            }

            errorMessage = FriendlyError.message(for: error)
        }

        session.presentationContextProvider = oauthPresenter
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }

    private var submitTitle: String {
        mode == .createAccount
        ? String(localized: "Create account")
        : String(localized: "Continue")
    }

    private var canSubmit: Bool {

        let trimmed = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty,
              InputValidator.validateEmail(trimmed),
              !password.isEmpty else {
            return false
        }

        if mode == .createAccount {
            return password.count >= 8
                && password == confirmPassword
        }

        return true
    }

    private func submit() {

        let trimmed = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email."
            return
        }

        if mode == .createAccount {

            guard password.count >= 8 else {
                errorMessage =
                    "Password must be at least 8 characters."
                return
            }

            guard password == confirmPassword else {
                errorMessage = "Passwords don't match."
                return
            }

        } else {

            guard !password.isEmpty else {
                errorMessage = "Enter your password."
                return
            }
        }

        errorMessage = nil
        isSubmitting = true

        Task {

            do {

                if mode == .createAccount {
                    try await userSession.signUp(
                        email: trimmed,
                        password: password
                    )
                } else {
                    try await userSession.signIn(
                        email: trimmed,
                        password: password
                    )
                }

                HapticEngine.success()
                dismiss()

            } catch let authError as SupabaseAuthService.AuthError {

                isSubmitting = false

                if case .emailConfirmationRequired = authError {
                    // Account was created; the user just needs to confirm.
                    toastCenter.show(
                        "Account created! Check your inbox to confirm your email, then sign in.",
                        kind: .success,
                        duration: 6
                    )
                    mode = .signIn
                    password = ""
                    confirmPassword = ""
                } else {
                    errorMessage = FriendlyError.message(for: authError)
                }

            } catch {

                isSubmitting = false
                errorMessage = FriendlyError.message(for: error)
            }
        }
    }

    private func handleAppleSignIn(
        _ result: Result<ASAuthorization, Error>
    ) {

        guard
            case .success(let authorization) = result,
            let credential =
                authorization.credential
                    as? ASAuthorizationAppleIDCredential
        else {
            if let error = result.failure {
                if (error as? ASAuthorizationError)?.code == .canceled {
                    return
                }
                errorMessage = FriendlyError.message(for: error)
            } else {
                errorMessage =
                    "Sign in with Apple failed. Please try again."
            }
            return
        }

        guard let rawNonce = currentNonce else {
            errorMessage =
                "Sign in with Apple failed. Please try again."
            return
        }

        errorMessage = nil
        isSubmitting = true

        Task {

            do {

                try await userSession.signInWithApple(
                    credential: credential,
                    rawNonce: rawNonce
                )

                HapticEngine.success()
                dismiss()

            } catch {

                isSubmitting = false
                errorMessage = FriendlyError.message(for: error)
            }
        }
    }
}

private extension Result where Success == ASAuthorization, Failure == Error {

    var failure: Error? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
}

struct LoginView_Previews: PreviewProvider {

    static var previews: some View {

        LoginView()
            .environmentObject(
                UserSession()
            )
            .environmentObject(
                ToastCenter()
            )
    }
}
