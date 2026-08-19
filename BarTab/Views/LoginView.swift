import SwiftUI
import AuthenticationServices

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
    @Environment(\.presentationMode) private var presentationMode

    @State private var mode: Mode = .signIn
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {

        NavigationView {

            ScrollView {

                VStack(spacing: 24) {

                    VStack(spacing: 8) {

                        ZStack {
                            Circle()
                                .fill(Color.barTabPrimary)
                                .frame(width: 84, height: 84)

                            Image(systemName: "wineglass.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.white)
                        }

                        Text("Welcome to BarTab")
                            .font(.system(size: 26, weight: .bold))

                        Text(
                            "Create an account to add and manage prices."
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)


                    SignInWithAppleButton(
                        .signIn
                    ) { request in

                        request.requestedScopes = [
                            .fullName,
                            .email
                        ]

                        let rawNonce =
                            AppleIDTokenValidator
                            .randomNonceString()

                        currentNonce = rawNonce
                        request.nonce =
                            AppleIDTokenValidator
                            .sha256(rawNonce)

                    } onCompletion: { result in

                        handleAppleSignIn(result)
                    }
                    .frame(height: 50)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
                    .signInWithAppleButtonStyle(
                        .whiteOutline
                    )
                    .disabled(isSubmitting)


                    HStack(spacing: 12) {

                        VStack { Divider() }

                        Text("or use a username")
                            .font(.caption)
                            .foregroundColor(.secondary)

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

                            Text("Username")
                                .font(.headline)

                            TextField(
                                "Your username",
                                text: $username
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(
                                Color.barTabPrimary
                                    .opacity(0.08)
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                            )
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            Text("Password")
                                .font(.headline)

                            SecureField(
                                mode == .createAccount
                                ? "At least 8 characters"
                                : "Your password",
                                text: $password
                            )
                            .padding()
                            .background(
                                Color.barTabPrimary
                                    .opacity(0.08)
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                            )
                        }

                        if mode == .createAccount {

                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {

                                Text("Confirm password")
                                    .font(.headline)

                                SecureField(
                                    "Repeat your password",
                                    text: $confirmPassword
                                )
                                .padding()
                                .background(
                                    Color.barTabPrimary
                                        .opacity(0.08)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                )
                            }
                        }
                    }


                    Button {
                        submit()
                    } label: {

                        Text(submitTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                canSubmit
                                ? Color.barTabPrimary
                                : Color.gray
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                    }
                    .disabled(!canSubmit || isSubmitting)


                    Text(
                        "Accounts are stored securely "
                        + "on this device only."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                    Spacer(minLength: 16)
                }
                .padding(24)
            }
            .background(Color.barTabBackground)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var submitTitle: String {
        mode == .createAccount
        ? "Create account"
        : "Continue"
    }

    private var canSubmit: Bool {

        let trimmed = username.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty,
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

        let trimmed = username.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            errorMessage = "Enter a username."
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

        isSubmitting = true

        do {

            if mode == .createAccount {
                try userSession.signUp(
                    username: trimmed,
                    password: password
                )
            } else {
                try userSession.signIn(
                    username: trimmed,
                    password: password
                )
            }

            presentationMode.wrappedValue.dismiss()

        } catch {

            isSubmitting = false
            errorMessage = error.localizedDescription
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
            errorMessage =
                "Sign in with Apple failed. Please try again."
            return
        }

        guard let rawNonce = currentNonce else {
            errorMessage =
                "Sign in with Apple failed. Please try again."
            return
        }

        isSubmitting = true

        userSession.signInWithApple(
            credential: credential,
            rawNonce: rawNonce
        ) { result in

            DispatchQueue.main.async { [self] in

                isSubmitting = false

                switch result {

                case .success:
                    presentationMode.wrappedValue.dismiss()

                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {

    static var previews: some View {

        LoginView()
            .environmentObject(
                UserSession()
            )
    }
}