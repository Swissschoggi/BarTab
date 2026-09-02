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

                BarTabScreenHeader(
                    title: "Find Friends",
                    subtitle: "Search by username to send a follow request."
                )

                HStack(spacing: BarTabSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.barTabSecondary)

                    TextField("Search username…", text: $query)
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
                                .foregroundColor(.barTabSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.barTabCardFill)
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                        .stroke(Color.barTabCardBorder, lineWidth: 1)
                )

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if hasSearched && results.isEmpty {
                    VStack(spacing: BarTabSpacing.sm) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)

                        Text("No users found")
                            .font(.barTabHeading)

                        Text("Try a different search term.")
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()
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
                    .barTabCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Find Friends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func userRow(_ profile: ProfileDTO) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(urlString: profile.avatar_url, displayName: profile.display_name)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.display_name ?? "User")
                    .font(.barTabBody)
                    .fontWeight(.medium)
                    .foregroundColor(.barTabText)

                if profile.is_admin {
                    Text("Admin")
                        .font(.barTabTiny)
                        .foregroundColor(.barTabAccent)
                }
            }

            Spacer()

            FollowButton(userID: profile.id)
        }
        .padding(.horizontal, BarTabSpacing.sm)
        .padding(.vertical, BarTabSpacing.sm)
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
