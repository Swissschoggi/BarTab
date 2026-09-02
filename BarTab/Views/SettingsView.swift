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
    @State private var currencyExpanded = false
    @State private var languageExpanded = false
    @State private var selectedCurrency: Currency = Currency.defaultCurrency
    @State private var showingClearCacheConfirm = false
    @State private var showingDeleteAccount = false

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
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabPrimary)
                                Text("Account")
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            }

                            VStack(spacing: 0) {
                                Button {
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

                    // Preferences (currency + language)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.barTabBody)
                                .foregroundColor(.barTabPrimary)
                            Text("Preferences")
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        DisclosureGroup(isExpanded: $currencyExpanded) {
                            VStack(spacing: 0) {
                                ForEach(Currency.allCases) { currency in
                                    Button {
                                        selectedCurrency = currency
                                        barRepository.setDefaultCurrency(currency)
                                    } label: {
                                        HStack {
                                            Text(currency.symbol)
                                                .font(.barTabHeading)
                                                .fontWeight(.semibold)
                                                .frame(width: 32)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(currency.rawValue)
                                                    .font(.barTabBody)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.barTabText)
                                                Text(currency.displayName)
                                                    .font(.barTabSmall)
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
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabPrimary)
                                Text("Currency")
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabText)

                                Spacer()

                                Text(selectedCurrency.rawValue)
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabSecondary)
                            }
                        }
                        .tint(.barTabSecondary)

                        Divider()
                            .foregroundColor(.barTabCardBorder)

                        DisclosureGroup(isExpanded: $languageExpanded) {
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
                                                .font(.barTabHeading)

                                            Text(lang.name)
                                                .font(.barTabBody)
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
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabPrimary)
                                Text("Language")
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabText)

                                Spacer()

                                Text(languages.first { $0.code == languageManager.selectedLanguage }?.name ?? "English")
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabSecondary)
                            }
                        }
                        .tint(.barTabSecondary)
                    }
                    .barTabCard()

                    // Admin section
                    if userSession.currentUser?.isAdmin == true {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabPrimary)
                                Text("Admin")
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            }

                            VStack(spacing: 0) {
                                NavigationLink {
                                    AdminBrandRequestsView()
                                } label: {
                                    HStack {
                                        Label("Brand Requests", systemImage: "tag.fill")
                                            .font(.barTabBody)
                                            .foregroundColor(.barTabText)

                                        Spacer()

                                        if barRepository.pendingBrandRequestCount > 0 {
                                            Text("\(barRepository.pendingBrandRequestCount)")
                                                .font(.barTabTiny)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.barTabWarning)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.barTabSmall)
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
                                            .font(.barTabBody)
                                            .foregroundColor(.barTabText)

                                        Spacer()

                                        if barRepository.unreviewedReportCount > 0 {
                                            Text("\(barRepository.unreviewedReportCount)")
                                                .font(.barTabTiny)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.barTabDanger)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.barTabSmall)
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
                                .font(.barTabBody)
                                .foregroundColor(.barTabPrimary)
                            Text("About")
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("BarTab")
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)

                            Text("Find bars, compare drinks, and discover the best drink deals around you.")
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)
                        }

                        Divider()
                            .foregroundColor(.barTabCardBorder)

                        HStack {
                            Text("Version")
                                .font(.barTabBody)
                                .foregroundColor(.barTabText)
                            Spacer()
                            Text("BETA")
                                .font(.barTabBody)
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                    .barTabCard()

                    // Cache
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.barTabBody)
                                .foregroundColor(.barTabPrimary)
                            Text("Cache")
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(spacing: 0) {
                            Button {
                                showingClearCacheConfirm = true
                            } label: {
                                settingsRow(
                                    icon: "xmark.circle",
                                    iconColor: .red,
                                    title: "Clear Cache",
                                    value: ""
                                )
                            }
                        }
                    }
                    .barTabCard()

                    // Support the Dev
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.barTabBody)
                                .foregroundColor(.barTabPrimary)
                            Text("Support the Dev")
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Buy the developer a drink!")
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)

                            Text("If BarTab helped you find your favorite spot, consider tipping. Every dollar goes toward keeping the app running.")
                                .font(.barTabSmall)
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

                    // Danger zone
                    if userSession.isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabDanger)
                                Text("Danger Zone")
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            }

                            VStack(spacing: 0) {
                                Button {
                                    showingDeleteAccount = true
                                } label: {
                                    settingsRow(
                                        icon: "trash",
                                        iconColor: .red,
                                        title: "Delete Account",
                                        value: ""
                                    )
                                    .foregroundColor(.barTabDanger)
                                }
                            }
                        }
                        .barTabCard()
                    }
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
        .alert("Clear Cache", isPresented: $showingClearCacheConfirm) {
            Button("Clear", role: .destructive) {
                ExchangeRateService.shared.clearCache()
                toastCenter.show("Cache cleared", kind: .success)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset exchange rates to default values.")
        }
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please close and reopen the app to apply the language change.")
        }
        .sheet(isPresented: $showingUsernameEditor) {
            EditUsernameSheet(currentUsername: userSession.currentUser?.username ?? "")
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        }
        .sheet(isPresented: $showingPasswordEditor) {
            ChangePasswordSheet()
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        }
        .sheet(isPresented: $showingDeleteAccount) {
            DeleteAccountSheet()
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        }
        .alert("Coming Soon", isPresented: $showingTipJar) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tip jar coming soon! We're setting up payments   stay tuned.")
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
                .font(.barTabBody)
                .foregroundColor(.barTabText)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.barTabBody)
                    .foregroundColor(.barTabSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.barTabSmall)
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

// MARK: - Edit Username Sheet

private struct EditUsernameSheet: View {

    let currentUsername: String

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanged: Bool {
        !trimmed.isEmpty && trimmed != currentUsername
    }

    private var validationError: String? {
        guard !trimmed.isEmpty else { return nil }
        return InputValidator.validateDisplayName(trimmed)
    }

    private var canSave: Bool {
        hasChanged && validationError == nil && !isSaving
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 14) {
                        avatarPreview

                        VStack(alignment: .leading, spacing: 2) {
                            Text("This is how others see you")
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)

                            Text(trimmed.isEmpty ? "No name yet" : trimmed)
                                .font(.barTabBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Preview")
                }

                Section {
                    TextField("Username", text: $username)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("New username")
                } footer: {
                    HStack(alignment: .top) {
                        if let error = validationError {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .foregroundColor(.barTabDanger)
                        } else {
                            Text("Pick a name your friends will recognize.")
                        }

                        Spacer()

                        Text("\(username.count)/\(InputValidator.maxDisplayNameLength)")
                            .foregroundColor(
                                username.count > InputValidator.maxDisplayNameLength
                                    ? .red
                                    : .barTabSecondary
                            )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Edit Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                username = currentUsername
                isFocused = true
            }
        }
    }

    private var avatarPreview: some View {
        ZStack {
            Circle()
                .fill(Color.barTabPrimary)
                .frame(width: 44, height: 44)

            Text(String(trimmed.prefix(1)).uppercased())
                .font(.barTabHeading)
                .foregroundColor(.white)
        }
    }

    private func save() async {
        isSaving = true
        do {
            try await userSession.updateUsername(trimmed)
            toastCenter.show("Username updated", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}

// MARK: - Change Password Sheet

private struct ChangePasswordSheet: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNew = false
    @State private var showConfirm = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case newPassword
        case confirmPassword
    }

    private var strength: PasswordStrength {
        PasswordStrength.evaluate(newPassword)
    }

    private var validationError: String? {
        if newPassword.isEmpty { return nil }
        if newPassword.count < 8 {
            return "Password must be at least 8 characters."
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return "Passwords don't match."
        }
        return nil
    }

    private var canSave: Bool {
        !newPassword.isEmpty
            && newPassword.count >= 8
            && newPassword == confirmPassword
            && !isSaving
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SecureField("New password", text: $newPassword)
                                .focused($focusedField, equals: .newPassword)
                                .textContentType(.newPassword)

                            Button {
                                showNew.toggle()
                            } label: {
                                Image(systemName: showNew ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.barTabSecondary)
                            }
                        }

                        if !newPassword.isEmpty {
                            strengthMeter
                        }
                    }
                } header: {
                    Text("New password")
                } footer: {
                    if let error = validationError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.barTabDanger)
                    } else if !newPassword.isEmpty {
                        Text(strength.hint)
                    }
                }

                Section {
                    HStack {
                        SecureField("Confirm password", text: $confirmPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .textContentType(.newPassword)

                        Button {
                            showConfirm.toggle()
                        } label: {
                            Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                } header: {
                    Text("Confirm")
                } footer: {
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords don't match.")
                            .foregroundColor(.barTabDanger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    private var strengthMeter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < strength.filledSegments ? strength.color : Color.barTabPrimary.opacity(0.12))
                        .frame(height: 4)
                }
            }

            Text(strength.label)
                .font(.barTabSmall)
                .fontWeight(.semibold)
                .foregroundColor(strength.color)
        }
    }

    private func save() async {
        isSaving = true
        do {
            try await userSession.updatePassword(newPassword)
            toastCenter.show("Password updated", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}

// MARK: - Delete Account Sheet

private struct DeleteAccountSheet: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var confirmationText = ""
    @State private var isDeleting = false

    private var isConfirmed: Bool {
        confirmationText == "DELETE"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 22) {

                ZStack {
                    Circle()
                        .fill(Color.barTabDanger.opacity(0.12))
                        .frame(width: 72, height: 72)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.barTabDanger)
                }
                .padding(.top, 24)

                VStack(spacing: 8) {
                    Text("Delete your account?")
                        .font(.barTabHeading)
                        .fontWeight(.bold)

                    Text("This permanently deletes your profile, prices, bars, ratings, and everything else you've contributed. This can't be undone.")
                        .font(.barTabBody)
                        .foregroundColor(.barTabSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Type DELETE to confirm")
                        .font(.barTabSmall)
                        .foregroundColor(.barTabSecondary)

                    TextField("DELETE", text: $confirmationText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Button {
                    Task { await delete() }
                } label: {
                    HStack(spacing: 8) {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Delete Account")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                    .background(
                        isConfirmed && !isDeleting
                            ? Color.barTabDanger
                            : Color.barTabSecondary.opacity(0.4)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                    )
                }
                .disabled(!isConfirmed || isDeleting)

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func delete() async {
        isDeleting = true
        do {
            try await userSession.deleteAccount()
            toastCenter.show("Account deleted", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isDeleting = false
    }
}

// MARK: - Password strength

private enum PasswordStrength {
    case weak
    case medium
    case strong

    var label: String {
        switch self {
        case .weak: return "Weak password"
        case .medium: return "Fair password"
        case .strong: return "Strong password"
        }
    }

    var hint: String {
        switch self {
        case .weak: return "Add numbers, symbols or uppercase letters."
        case .medium: return "Good   add more variety for extra strength."
        case .strong: return "Nice, that's a strong password."
        }
    }

    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var filledSegments: Int {
        switch self {
        case .weak: return 1
        case .medium: return 2
        case .strong: return 3
        }
    }

    static func evaluate(_ password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .weak }

        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }

        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbol = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil

        let variety = [hasUpper, hasLower, hasDigit, hasSymbol].filter { $0 }.count
        if variety >= 3 { score += 1 }
        if variety >= 4 { score += 1 }

        switch score {
        case 0...1: return .weak
        case 2...3: return .medium
        default: return .strong
        }
    }
}