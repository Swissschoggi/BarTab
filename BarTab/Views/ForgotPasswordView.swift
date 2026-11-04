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

                BartapScreenHeader(
                    title: String(localized: "Reset Password"),
                    subtitle: String(localized: "Enter your email and we'll send you a reset link.")
                )

                if didSend {
                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "envelope.badge")
                            .font(.BartapEmptyIconLarge)
                            .foregroundColor(.BartapAccent)

                        Text(String(localized: "Check your inbox"))
                            .font(.title3.bold())

                        Text(String(localized: "We sent a password reset link to **\(email)**. Follow the link to set a new password."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(String(localized: "Back to Sign In")) {
                            dismiss()
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.BartapPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Email"))
                            .font(.BartapHeading)

                        TextField(String(localized: "your@email.com"), text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.BartapPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text(String(localized: "Send Reset Link"))
                        }
                        .font(.BartapHeading)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isEmailValid && !isSubmitting
                                ? Color.BartapPrimary
                                : Color.gray
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
                    }
                    .disabled(!isEmailValid || isSubmitting)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(String(localized: "Reset Password"))
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
