import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var showingRestartAlert = false
    @State private var showingUsernameEditor = false
    @State private var showingPasswordEditor = false
    @State private var showingTipJar = false
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var currencyExpanded = false
    @State private var selectedCurrency: Currency = Currency.defaultCurrency

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

                    // Currency (collapsible)
                    VStack(alignment: .leading, spacing: 12) {
                        DisclosureGroup(isExpanded: $currencyExpanded) {
                            VStack(spacing: 0) {
                                ForEach(Currency.allCases) { currency in
                                    Button {
                                        selectedCurrency = currency
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

                                            if selectedCurrency == currency {
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
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.barTabPrimary)
                                Text("Default Currency")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)

                                Spacer()

                                HStack(spacing: 4) {
                                    Text(selectedCurrency.symbol)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(selectedCurrency.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }
                        }
                        .tint(.barTabSecondary)
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

                    // Admin section
                    if userSession.currentUser?.isAdmin == true {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.subheadline)
                                    .foregroundColor(.barTabPrimary)
                                Text("Admin")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            }

                            VStack(spacing: 0) {
                                NavigationLink {
                                    AdminBrandRequestsView()
                                } label: {
                                    HStack {
                                        Label("Brand Requests", systemImage: "tag.fill")
                                            .font(.subheadline)
                                            .foregroundColor(.barTabText)

                                        Spacer()

                                        if barRepository.pendingBrandRequestCount > 0 {
                                            Text("\(barRepository.pendingBrandRequestCount)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.orange)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.barTabSecondary)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                }

                                Divider()
                                    .foregroundColor(.barTabCardBorder)
                                    .padding(.leading, 44)

                                NavigationLink {
                                    AdminReportsView()
                                } label: {
                                    HStack {
                                        Label("Reported Content", systemImage: "exclamationmark.shield.fill")
                                            .font(.subheadline)
                                            .foregroundColor(.barTabText)

                                        Spacer()

                                        if barRepository.unreviewedReportCount > 0 {
                                            Text("\(barRepository.unreviewedReportCount)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.red)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.barTabSecondary)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                        .barTabCard()
                    }

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
                            Text("BETA")
                                .font(.subheadline)
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                    .barTabCard()

                    // Support the Dev
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.subheadline)
                                .foregroundColor(.barTabPrimary)
                            Text("Support the Dev")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Buy the developer a drink!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)

                            Text("If BarTab helped you find your favorite spot, consider tipping. Every dollar goes toward keeping the app running.")
                                .font(.caption)
                                .foregroundColor(.barTabSecondary)
                        }

                        Button {
                            showingTipJar = true
                        } label: {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                Text("Buy a Drink")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .barTabPrimaryButton()
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
                let trimmed = newUsername.trimmingCharacters(in: .whitespaces)
                if let error = InputValidator.validateDisplayName(trimmed) {
                    toastCenter.show(error, kind: .error)
                    return
                }
                Task {
                    do {
                        try await userSession.updateUsername(trimmed)
                        toastCenter.show(
                            "Username updated",
                            kind: .success
                        )
                    } catch {
                        toastCenter.showError(error)
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
                guard newPassword.count >= 8 else {
                    toastCenter.show(
                        "Password must be at least 8 characters.",
                        kind: .error
                    )
                    return
                }
                guard newPassword == confirmPassword else {
                    toastCenter.show(
                        "Passwords do not match.",
                        kind: .error
                    )
                    return
                }
                Task {
                    do {
                        try await userSession.updatePassword(newPassword)
                        toastCenter.show(
                            "Password updated",
                            kind: .success
                        )
                        newPassword = ""
                        confirmPassword = ""
                    } catch {
                        toastCenter.showError(error)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                newPassword = ""
                confirmPassword = ""
            }
        } message: {
            Text("Enter your new password (at least 8 characters).")
        }
        .alert("Coming Soon", isPresented: $showingTipJar) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tip jar coming soon! We're setting up payments — stay tuned.")
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
            .environmentObject(ToastCenter())
    }
}
