import SwiftUI

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
                    .cornerRadius(12)
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
                        .cornerRadius(14)
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
}

struct LoginView_Previews: PreviewProvider {

    static var previews: some View {

        LoginView()
            .environmentObject(
                UserSession()
            )
    }
}
