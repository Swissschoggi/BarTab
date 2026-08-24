import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingRestartAlert = false
    @State private var showingUsernameEditor = false
    @State private var showingPasswordEditor = false
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let languages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪"),
        ("fr", "Français", "🇫🇷"),
        ("it", "Italiano", "🇮🇹")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Account section
                    if userSession.isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.barTabPrimary)
                                Text("Account")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            }

                            VStack(spacing: 0) {
                                Button {
                                    newUsername = userSession.currentUser?.username ?? ""
                                    showingUsernameEditor = true
                                } label: {
                                    settingsRow(
                                        icon: "person.fill",
                                        iconColor: .barTabPrimary,
                                        title: "Username",
                                        value: userSession.currentUser?.username ?? "Not set"
                                    )
                                }

                                Divider()
                                    .foregroundColor(.barTabCardBorder)
                                    .padding(.leading, 44)

                                Button {
                                    newPassword = ""
                                    confirmPassword = ""
                                    showingPasswordEditor = true
                                } label: {
                                    settingsRow(
                                        icon: "lock.fill",
                                        iconColor: .barTabPrimary,
                                        title: "Change Password",
                                        value: ""
                                    )
                                }
                            }
                        }
                        .barTabCard()
                    }

                    // Currency
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "dollarsign.circle")
                                .font(.subheadline)
                                .foregroundColor(.barTabPrimary)
                            Text("Default Currency")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(spacing: 0) {
                            ForEach(Currency.allCases) { currency in
                                Button {
                                    Currency.defaultCurrency = currency
                                } label: {
                                    HStack {
                                        Text(currency.symbol)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .frame(width: 32)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(currency.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.barTabText)
                                            Text(currency.displayName)
                                                .font(.caption)
                                                .foregroundColor(.barTabSecondary)
                                        }

                                        Spacer()

                                        if Currency.defaultCurrency == currency {
                                            Image(systemName: "checkmark.circle.fill")
                                                .fontWeight(.semibold)
                                                .foregroundColor(.barTabPrimary)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.barTabCardBorder)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                }

                                if currency != Currency.allCases.last {
                                    Divider()
                                        .foregroundColor(.barTabCardBorder)
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    }
                    .barTabCard()

                    // Language
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.subheadline)
                                .foregroundColor(.barTabPrimary)
                            Text("Language")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(languages.enumerated()), id: \.element.code) { index, lang in
                                Button {
                                    guard languageManager.selectedLanguage != lang.code else { return }
                                    languageManager.selectedLanguage = lang.code
                                    UserDefaults.standard.set([lang.code], forKey: "AppleLanguages")
                                    showingRestartAlert = true
                                } label: {
                                    HStack {
                                        Text(lang.flag)
                                            .font(.title3)

                                        Text(lang.name)
                                            .font(.subheadline)
                                            .foregroundColor(.barTabText)

                                        Spacer()

                                        if languageManager.selectedLanguage == lang.code {
                                            Image(systemName: "checkmark.circle.fill")
                                                .fontWeight(.semibold)
                                                .foregroundColor(.barTabPrimary)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.barTabCardBorder)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                }

                                if index < languages.count - 1 {
                                    Divider()
                                        .foregroundColor(.barTabCardBorder)
                                }
                            }
                        }
                    }
                    .barTabCard()

                    // About
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .foregroundColor(.barTabPrimary)
                            Text("About")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("BarTab")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)

                            Text("Find bars, compare drinks, and discover the best drink deals around you.")
                                .font(.caption)
                                .foregroundColor(.barTabSecondary)
                        }

                        Divider()
                            .foregroundColor(.barTabCardBorder)

                        HStack {
                            Text("Version")
                                .font(.subheadline)
                                .foregroundColor(.barTabText)
                            Spacer()
                            Text("1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                    .barTabCard()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("Restart Now") {
                exit(0)
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Please restart the app to apply the language change.")
        }
        .alert("Edit Username", isPresented: $showingUsernameEditor) {
            TextField("Username", text: $newUsername)
            Button("Save") {
                guard !newUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    do {
                        try await userSession.updateUsername(newUsername.trimmingCharacters(in: .whitespaces))
                        successMessage = "Username updated"
                        errorMessage = nil
                    } catch {
                        errorMessage = "Could not update username: \(error.localizedDescription)"
                        successMessage = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your new display name.")
        }
        .alert("Change Password", isPresented: $showingPasswordEditor) {
            SecureField("New password", text: $newPassword)
            SecureField("Confirm password", text: $confirmPassword)
            Button("Update") {
                guard newPassword.count >= 6 else {
                    errorMessage = "Password must be at least 6 characters."
                    return
                }
                guard newPassword == confirmPassword else {
                    errorMessage = "Passwords do not match."
                    return
                }
                Task {
                    do {
                        try await userSession.updatePassword(newPassword)
                        successMessage = "Password updated"
                        errorMessage = nil
                        newPassword = ""
                        confirmPassword = ""
                    } catch {
                        errorMessage = "Could not update password: \(error.localizedDescription)"
                        successMessage = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                newPassword = ""
                confirmPassword = ""
            }
        } message: {
            Text("Enter your new password (at least 6 characters).")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Success",
            isPresented: Binding(
                get: { successMessage != nil },
                set: { if !$0 { successMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
        }
    }

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.barTabText)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.barTabSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.barTabSecondary)
        }
        .padding(.vertical, 12)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSession())
            .environmentObject(BarRepository())
            .environmentObject(LanguageManager.shared)
    }
}
