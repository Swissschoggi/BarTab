import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @Environment(\.dismiss) private var dismiss

    @AppStorage("selectedLanguage") private var selectedLanguage = "en"

    private let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("de", "Deutsch"),
        ("fr", "Francais"),
        ("it", "Italiano")
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
                VStack(alignment: .leading, spacing: 24) {

                    // Language
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Language", systemImage: "globe")
                            .font(.headline)

                        ForEach(languages, id: \.code) { lang in
                            Button {
                                withAnimation {
                                    selectedLanguage = lang.code
                                }
                            } label: {
                                HStack {
                                    Text(lang.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if selectedLanguage == lang.code {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.barTabPrimary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .barTabCard()

                    // About
                    VStack(alignment: .leading, spacing: 10) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("BarTab")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Find bars, compare prices, and discover the best drink deals around you.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            Text("Version")
                                .font(.subheadline)
                            Spacer()
                            Text("1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSession())
            .environmentObject(BarRepository())
    }
}
