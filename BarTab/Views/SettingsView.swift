import SwiftUI
#if canImport(StripePaymentSheet)
import StripePaymentSheet
#endif

struct SettingsView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var showingRestartAlert = false
    @State private var showingUsernameEditor = false
    @State private var showingPasswordEditor = false

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    // Account section
                    if userSession.isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle")
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapPrimary)
                                Text(String(localized: "Account"))
                                    .font(.BartapBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.BartapText)
                            }

                            VStack(spacing: 0) {
                                Button {
                                    showingUsernameEditor = true
                                } label: {
                                    settingsRow(
                                        icon: "person.fill",
                                        iconColor: .BartapPrimary,
                                        title: String(localized: "Username"),
                                        value: userSession.currentUser?.username ?? String(localized: "Not set")
                                    )
                                }

                                Divider()
                                    .foregroundColor(.BartapCardBorder)
                                    .padding(.leading, BartapSpacing.md)

                                Button {
                                    showingPasswordEditor = true
                                } label: {
                                    settingsRow(
                                        icon: "lock.fill",
                                        iconColor: .BartapPrimary,
                                        title: String(localized: "Change Password"),
                                        value: ""
                                    )
                                }
                            }
                        }
                        .BartapCard()
                    }

                    // Preferences (currency + language)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            Text(String(localized: "Preferences"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
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
                                                .font(.BartapHeading)
                                                .fontWeight(.semibold)
                                                .frame(width: 32)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(currency.rawValue)
                                                    .font(.BartapBody)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.BartapText)
                                                Text(currency.displayName)
                                                    .font(.BartapSmall)
                                                    .foregroundColor(.BartapSecondary)
                                            }

                                            Spacer()

                                            if selectedCurrency == currency {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.BartapPrimary)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.BartapCardBorder)
                                            }
                                        }
                                        .padding(.vertical, BartapSpacing.sm)
                                    }

                                    if currency != Currency.allCases.last {
                                        Divider()
                                            .foregroundColor(.BartapCardBorder)
                                            .padding(.leading, BartapSpacing.md)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapPrimary)
                                Text(String(localized: "Currency"))
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapText)

                                Spacer()

                                Text(selectedCurrency.rawValue)
                                    .font(.BartapBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.BartapSecondary)
                            }
                        }
                        .tint(.BartapSecondary)

                        Divider()
                            .foregroundColor(.BartapCardBorder)

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
                                                .font(.BartapHeading)

                                            Text(lang.name)
                                                .font(.BartapBody)
                                                .foregroundColor(.BartapText)

                                            Spacer()

                                            if languageManager.selectedLanguage == lang.code {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.BartapPrimary)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.BartapCardBorder)
                                            }
                                        }
        .padding(.vertical, BartapSpacing.sm)
                                    }

                                    if index < languages.count - 1 {
                                        Divider()
                                            .foregroundColor(.BartapCardBorder)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapPrimary)
                                Text(String(localized: "Language"))
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapText)

                                Spacer()

                                Text(languages.first { $0.code == languageManager.selectedLanguage }?.name ?? "English")
                                    .font(.BartapBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.BartapSecondary)
                            }
                        }
                        .tint(.BartapSecondary)
                    }
                    .BartapCard()

                    // Admin section
                    if userSession.currentUser?.isAdmin == true {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapPrimary)
                                Text(String(localized: "Admin"))
                                    .font(.BartapBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.BartapText)
                            }

                            VStack(spacing: 0) {
                                NavigationLink {
                                    AdminBrandRequestsView()
                                } label: {
                                    HStack {
                                        Label(String(localized: "Brand Requests"), systemImage: "tag.fill")
                                            .font(.BartapBody)
                                            .foregroundColor(.BartapText)

                                        Spacer()

                                        if barRepository.pendingBrandRequestCount > 0 {
                                            Text("\(barRepository.pendingBrandRequestCount)")
                                                .font(.BartapTiny)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.BartapWarning)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.BartapTiny)
                                            .foregroundColor(.BartapSecondary)
                                    }
                                    .padding(.vertical, BartapSpacing.sm)
                                    .padding(.horizontal, 12)
                                }

                                Divider()
                                    .foregroundColor(.BartapCardBorder)
                                    .padding(.leading, BartapSpacing.md)

                                NavigationLink {
                                    AdminReportsView()
                                } label: {
                                    HStack {
                                        Label(String(localized: "Reported Content"), systemImage: "exclamationmark.shield.fill")
                                            .font(.BartapBody)
                                            .foregroundColor(.BartapText)

                                        Spacer()

                                        if barRepository.unreviewedReportCount > 0 {
                                            Text("\(barRepository.unreviewedReportCount)")
                                                .font(.BartapTiny)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Color.BartapDanger)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.BartapTiny)
                                            .foregroundColor(.BartapSecondary)
                                    }
                                    .padding(.vertical, BartapSpacing.sm)
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                        .BartapCard()
                    }

                    // About
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            Text(String(localized: "About"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bartap")
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)

                            Text(String(localized: "Find bars, compare drinks, and discover the best drink deals around you."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                        }

                        Divider()
                            .foregroundColor(.BartapCardBorder)

                        HStack {
                            Text(String(localized: "Version"))
                                .font(.BartapBody)
                                .foregroundColor(.BartapText)
                            Spacer()
                            Text(appVersionString)
                                .font(.BartapBody)
                                .foregroundColor(.BartapSecondary)
                        }
                    }
                    .BartapCard()

                    // Cache
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            Text(String(localized: "Cache"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
                        }

                        VStack(spacing: 0) {
                            Button {
                                showingClearCacheConfirm = true
                            } label: {
                                settingsRow(
                                    icon: "xmark.circle",
                                    iconColor: .red,
                                    title: String(localized: "Clear Cache"),
                                    value: ""
                                )
                            }
                        }
                    }
                    .BartapCard()

                    // Onboarding
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            Text(String(localized: "Onboarding"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
                        }

                        VStack(spacing: 0) {
                            Button {
                                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                                toastCenter.show(
                                    String(localized: "Restart Bartap to replay onboarding"),
                                    kind: .success
                                )
                            } label: {
                                settingsRow(
                                    icon: "arrow.counterclockwise",
                                    iconColor: .BartapAccent,
                                    title: String(localized: "Replay Onboarding"),
                                    value: ""
                                )
                            }
                        }
                    }
                    .BartapCard()

                    // Support the Dev
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            Text(String(localized: "Support the Dev"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Buy the developer a drink!"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)

                            Text(String(localized: "Bartap isn't on the App Store yet because I can't afford Apple's yearly developer fee. Donations help me afford it."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)

                            Text(String(localized: "If Bartap helped you find your favorite spot, consider tipping. Every dollar goes toward keeping the app running."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                        }

                        Button {
                            showingTipJar = true
                        } label: {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                Text(String(localized: "Buy a Drink"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BartapSpacing.sm)
                            .BartapPrimaryButton()
                        }

                        Link(destination: URL(string: "https://ko-fi.com/bartap")!) {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text(String(localized: "Donate on Ko-fi"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BartapSpacing.sm)
                            .BartapPrimaryButton()
                        }
                    }
                    .BartapCard()

                    // Legal
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            Text(String(localized: "Legal"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
                        }

                        VStack(spacing: 0) {
                            Link(destination: URL(string: "https://bartap.info/privacy.html")!) {
                                settingsRow(
                                    icon: "hand.raised",
                                    iconColor: .BartapPrimary,
                                    title: String(localized: "Privacy Policy"),
                                    value: ""
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .foregroundColor(.BartapCardBorder)
                                .padding(.leading, BartapSpacing.md)

                            Link(destination: URL(string: "https://bartap.info/terms.html")!) {
                                settingsRow(
                                    icon: "doc.plaintext",
                                    iconColor: .BartapPrimary,
                                    title: String(localized: "Terms of Service"),
                                    value: ""
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .BartapCard()

                    // Danger zone
                    if userSession.isLoggedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapDanger)
                                Text(String(localized: "Danger Zone"))
                                    .font(.BartapBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.BartapText)
                            }

                            VStack(spacing: 0) {
                                Button {
                                    showingDeleteAccount = true
                                } label: {
                                    settingsRow(
                                        icon: "trash",
                                        iconColor: .red,
                                        title: String(localized: "Delete Account"),
                                        value: ""
                                    )
                                    .foregroundColor(.BartapDanger)
                                }
                            }
                        }
                        .BartapCard()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .alert(String(localized: "Clear Cache"), isPresented: $showingClearCacheConfirm) {
            Button(String(localized: "Clear"), role: .destructive) {
                ExchangeRateService.shared.clearCache()
                toastCenter.show(String(localized: "Cache cleared"), kind: .success)
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This will reset exchange rates to default values."))
        }
        .alert(String(localized: "Restart Required"), isPresented: $showingRestartAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Please close and reopen the app to apply the language change."))
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
        .sheet(isPresented: $showingTipJar) {
            tipJarSheet
        }
    }

    @ViewBuilder
    private var tipJarSheet: some View {
        #if canImport(StripePaymentSheet)
        TipJarSheet()
            .environmentObject(toastCenter)
        #else
        Text(String(localized: "Tip jar coming soon! We're setting up payments   stay tuned."))
            .font(.BartapBody)
            .multilineTextAlignment(.center)
            .padding()
            .presentationDetents([.height(160)])
        #endif
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
                .font(.BartapBody)
                .foregroundColor(.BartapText)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.BartapBody)
                    .foregroundColor(.BartapSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.BartapTiny)
                .foregroundColor(.BartapSecondary)
        }
        .padding(.vertical, BartapSpacing.sm)
    }
}

#if canImport(StripePaymentSheet)

private struct TipJarSheet: View {
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var paymentSheet: PaymentSheet?
    @State private var isBusy = false

    private let tips: [Int] = [300, 500, 1000]

    var body: some View {
        NavigationStack {
            VStack(spacing: BartapSpacing.lg) {
                Spacer()

                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.BartapPrimary)

                Text(String(localized: "Buy the developer a drink!"))
                    .font(.BartapTitle)
                    .multilineTextAlignment(.center)

                Text(String(localized: "If Bartap helped you find your favorite spot, consider tipping. Every dollar goes toward keeping the app running."))
                    .font(.BartapBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: BartapSpacing.md) {
                    ForEach(tips, id: \.self) { amount in
                        Button {
                            Task { await startCheckout(amount) }
                        } label: {
                            Text("\(Currency.defaultCurrency.symbol) \((Decimal(amount) / 100).formattedAmount)")
                                .font(.BartapHeading)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .BartapPrimaryButton()
                        }
                        .disabled(isBusy)
                    }
                }

                Spacer()
            }
            .padding(BartapSpacing.lg)
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Support the Dev"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }

    private func startCheckout(_ amount: Int) async {
        isBusy = true
        defer { isBusy = false }

        StripeAPI.defaultPublishableKey = SupabaseConfig.stripePublishableKey

        guard let secret = await createPaymentIntent(amount: amount) else {
            toastCenter.show(String(localized: "Couldn't start the tip. Please try again."), kind: .error)
            return
        }

        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Bartap"
        let sheet = PaymentSheet(paymentIntentClientSecret: secret, configuration: config)
        paymentSheet = sheet

        guard let presenter = UIViewController.top() else { return }
        sheet.present(from: presenter) { result in
            switch result {
            case .completed:
                toastCenter.show(String(localized: "Thanks for the tip! 🍻"), kind: .success)
                dismiss()
            case .canceled:
                break
            case .failed(let error):
                toastCenter.show(error.localizedDescription, kind: .error)
            }
        }
    }

    private func createPaymentIntent(amount: Int) async -> String? {
        let host = SupabaseConfig.projectURL.host ?? ""
        guard let url = URL(string: "https://\(host)/functions/v1/create-payment-intent") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "amount": amount,
            "currency": Currency.defaultCurrency.rawValue.lowercased()
        ])

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["clientSecret"] as? String
    }
}

private extension UIViewController {
    static func top() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

#endif

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
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: BartapSpacing.sm) {
                        avatarPreview

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "This is how others see you"))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)

                            Text(trimmed.isEmpty ? String(localized: "No name yet") : trimmed)
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .foregroundColor(.BartapText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text(String(localized: "Preview"))
                }

                Section {
                    TextField(String(localized: "Username"), text: $username)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "New username"))
                } footer: {
                    HStack(alignment: .top) {
                        if let error = validationError {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .foregroundColor(.BartapDanger)
                        } else {
                            Text(String(localized: "Pick a name your friends will recognize."))
                        }

                        Spacer()

                        Text("\(username.count)/\(InputValidator.maxDisplayNameLength)")
                            .foregroundColor(
                                username.count > InputValidator.maxDisplayNameLength
                                    ? .red
                                    : .BartapSecondary
                            )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Edit Username"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
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
                .fill(Color.BartapPrimary)
                .frame(width: 44, height: 44)

            Text(String(trimmed.prefix(1)).uppercased())
                .font(.BartapHeading)
                .foregroundColor(.white)
        }
    }

    private func save() async {
        isSaving = true
        do {
            try await userSession.updateUsername(trimmed)
            toastCenter.show(String(localized: "Username updated"), kind: .success)
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
            return String(localized: "Password must be at least 8 characters.")
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return String(localized: "Passwords don't match.")
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
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        HStack {
                            SecureField(String(localized: "New password"), text: $newPassword)
                                .focused($focusedField, equals: .newPassword)
                                .textContentType(.newPassword)

                            Button {
                                showNew.toggle()
                            } label: {
                                Image(systemName: showNew ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.BartapSecondary)
                            }
                        }

                        if !newPassword.isEmpty {
                            strengthMeter
                        }
                    }
                } header: {
                    Text(String(localized: "New password"))
                } footer: {
                    if let error = validationError {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.BartapDanger)
                    } else if !newPassword.isEmpty {
                        Text(strength.hint)
                    }
                }

                Section {
                    HStack {
                        SecureField(String(localized: "Confirm password"), text: $confirmPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .textContentType(.newPassword)

                        Button {
                            showConfirm.toggle()
                        } label: {
                            Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.BartapSecondary)
                        }
                    }
                } header: {
                    Text(String(localized: "Confirm"))
                } footer: {
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text(String(localized: "Passwords don't match."))
                            .foregroundColor(.BartapDanger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Change Password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Update")) {
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
                        .fill(index < strength.filledSegments ? strength.color : Color.BartapPrimary.opacity(0.12))
                        .frame(height: 4)
                }
            }

            Text(strength.label)
                .font(.BartapSmall)
                .fontWeight(.semibold)
                .foregroundColor(strength.color)
        }
    }

    private func save() async {
        isSaving = true
        do {
            try await userSession.updatePassword(newPassword)
            toastCenter.show(String(localized: "Password updated"), kind: .success)
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
        NavigationStack {
            VStack(spacing: 22) {

                ZStack {
                    Circle()
                        .fill(Color.BartapDanger.opacity(0.12))
                        .frame(width: 72, height: 72)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.BartapDanger)
                }
                .padding(.top, 24)

                VStack(spacing: 8) {
                    Text(String(localized: "Delete your account?"))
                        .font(.BartapHeading)
                        .fontWeight(.bold)

                    Text(String(localized: "This permanently deletes your profile, prices, bars, ratings, and everything else you've contributed. This can't be undone."))
                        .font(.BartapBody)
                        .foregroundColor(.BartapSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Type DELETE to confirm"))
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)

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
                        Text(String(localized: "Delete Account"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                    .background(
                        isConfirmed && !isDeleting
                            ? Color.BartapDanger
                            : Color.BartapSecondary.opacity(0.4)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                    )
                }
                .disabled(!isConfirmed || isDeleting)

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Delete Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
    }

    private func delete() async {
        isDeleting = true
        do {
            try await userSession.deleteAccount()
            toastCenter.show(String(localized: "Account deleted"), kind: .success)
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
        case .weak: return String(localized: "Weak password")
        case .medium: return String(localized: "Fair password")
        case .strong: return String(localized: "Strong password")
        }
    }

    var hint: String {
        switch self {
        case .weak: return String(localized: "Add numbers, symbols or uppercase letters.")
        case .medium: return String(localized: "Good   add more variety for extra strength.")
        case .strong: return String(localized: "Nice, that's a strong password.")
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