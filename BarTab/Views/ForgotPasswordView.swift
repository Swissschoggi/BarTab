import SwiftUI

struct ForgotPasswordView: View {

    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var didSend = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                BarTabScreenHeader(
                    title: "Reset Password",
                    subtitle: "Enter your email and we'll send you a reset link."
                )

                if didSend {
                    VStack(spacing: BarTabSpacing.sm) {
                        Image(systemName: "envelope.badge.checkmark")
                            .font(.barTabEmptyIconLarge)
                            .foregroundColor(.barTabAccent)

                        Text("Check your inbox")
                            .font(.title3.bold())

                        Text("We sent a password reset link to **\(email)**. Follow the link to set a new password.")
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Back to Sign In") {
                            dismiss()
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.barTabPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.barTabHeading)

                        TextField("your@email.com", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.barTabPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text("Send Reset Link")
                        }
                        .font(.barTabHeading)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isEmailValid && !isSubmitting
                                ? Color.barTabPrimary
                                : Color.gray
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                    }
                    .disabled(!isEmailValid || isSubmitting)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isEmailValid: Bool {
        email.trimmingCharacters(in: .whitespaces).contains("@")
    }

    private func submit() async {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        do {
            try await SupabaseAuthService().resetPassword(email: trimmed)
            didSend = true
        } catch {
            toastCenter.showError(error)
        }
        isSubmitting = false
    }
}
