import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingRestartAlert = false

    private let languages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇬🇧"),
        ("de", "Deutsch", "🇩🇪"),
        ("fr", "Français", "🇫🇷"),
        ("it", "Italiano", "🇮🇹")
    ]

    private var totalContributions: Int {
        guard let user = userSession.currentUser else { return 0 }
        let prices = barRepository.getPrices(reportedBy: user).count
        let bars = barRepository.getBars().filter { $0.createdBy == user.id }.count
        return prices + bars
    }

    private var currentLevel: UserLevel {
        .current(for: totalContributions)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

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
