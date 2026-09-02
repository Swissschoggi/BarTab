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

                HStack(spacing: 10) {
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.barTabCardBorder, lineWidth: 1)
                )

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if hasSearched && results.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)

                        Text("No users found")
                            .font(.headline)

                        Text("Try a different search term.")
                            .font(.subheadline)
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
            Circle()
                .fill(Color.barTabPrimary.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((profile.display_name ?? "U").prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.barTabPrimary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.display_name ?? "User")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.barTabText)

                if profile.is_admin {
                    Text("Admin")
                        .font(.caption2)
                        .foregroundColor(.barTabAccent)
                }
            }

            Spacer()

            FollowButton(userID: profile.id)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
