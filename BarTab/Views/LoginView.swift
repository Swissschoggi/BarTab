import SwiftUI
import AuthenticationServices

struct LoginView: View {

    @EnvironmentObject private var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @State private var username = ""

    var body: some View {

        NavigationView {

            VStack(spacing: 24) {

                Spacer()


                ZStack {
                    Circle()
                        .fill(Color.barTabPrimary)
                        .frame(width: 90, height: 90)

                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {

                    Text("Welcome to BarTab")
                        .font(.system(size: 28, weight: .bold))

                    Text(
                        "Create an account to add and manage prices."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }


                SignInWithAppleButton(
                    .signIn
                ) { request in

                    request.requestedScopes = [
                        .fullName,
                        .email
                    ]

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


                HStack(spacing: 12) {

                    VStack { Divider() }

                    Text("or use a username")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack { Divider() }
                }


                VStack(alignment: .leading, spacing: 8) {

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
                        Color.barTabPrimary.opacity(0.08)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )
                }


                Button {

                    let trimmedUsername =
                        username.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                    guard !trimmedUsername.isEmpty else {
                        return
                    }

                    userSession.login(
                        username: trimmedUsername
                    )

                    presentationMode.wrappedValue.dismiss()

                } label: {

                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            username.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                            ? Color.gray
                            : Color.barTabPrimary
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                }
                .disabled(
                    username.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )

                Text(
                    "Account creation will be connected to a real backend later."
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
            .background(Color.barTabBackground)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
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
            return
        }

        let name = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        userSession.login(
            appleUserID: credential.user,
            username: name.isEmpty
                ? "Apple User"
                : name
        )

        presentationMode.wrappedValue.dismiss()
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
