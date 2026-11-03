import SwiftUI

struct FindUsersView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var query = ""
    @State private var results: [ProfileDTO] = []
    @State private var isLoading = false
    @State private var hasSearched = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BartapScreenHeader(
                    title: String(localized: "Find Friends"),
                    subtitle: String(localized: "Search by username to send a follow request.")
                )

                HStack(spacing: BartapSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.BartapSecondary)

                    TextField(String(localized: "Search username…"), text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            Task { await search() }
                        }

                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.BartapSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.BartapCardFill)
                .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                        .stroke(Color.BartapCardBorder, lineWidth: 1)
                )

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if hasSearched && results.isEmpty {
                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)

                        Text(String(localized: "No users found"))
                            .font(.BartapHeading)

                        Text(String(localized: "Try a different search term."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()
                } else if !results.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { profile in
                            userRow(profile)
                            if profile.id != results.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .BartapCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Find Friends"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func userRow(_ profile: ProfileDTO) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(urlString: profile.avatar_url, displayName: profile.display_name)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.display_name ?? String(localized: "User"))
                    .font(.BartapBody)
                    .fontWeight(.medium)
                    .foregroundColor(.BartapText)

                if profile.is_admin {
                    Text(String(localized: "Admin"))
                        .font(.BartapTiny)
                        .foregroundColor(.BartapAccent)
                }
            }

            Spacer()

            FollowButton(userID: profile.id)
        }
        .padding(.horizontal, BartapSpacing.sm)
        .padding(.vertical, BartapSpacing.sm)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        hasSearched = true
        do {
            results = try await SupabaseClient.shared.searchUsers(query: trimmed)
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }
}
