import SwiftUI

struct InviteMemberSheet: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var following: [UUID] = []
    @State private var members: Set<UUID> = []
    @State private var userCache: [UUID: String] = [:]
    @State private var avatarCache: [UUID: String] = [:]
    @State private var isLoading = true
    @State private var searchText = ""

    private var filteredFriends: [UUID] {
        let notInGroup = following.filter { !members.contains($0) }
        return searchText.isEmpty
            ? notInGroup
            : notInGroup.filter { userCache[$0]?.localizedCaseInsensitiveContains(searchText) == true }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search friends...", text: $searchText)
                                .textFieldStyle(.plain)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.barTabPillFill)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))
                        .padding(.horizontal)
                        .padding(.top, 8)

                        List {
                            if filteredFriends.isEmpty {
                                Text(searchText.isEmpty
                                    ? "All your friends are already in this group."
                                    : "No friends match your search.")
                                    .font(.barTabBody)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(filteredFriends, id: \.self) { userID in
                                    Button {
                                        Task { await invite(userID) }
                                    } label: {
                                        HStack {
                                            UserAvatarView(urlString: avatarCache[userID], displayName: userCache[userID], size: 32)
                                            Text(userCache[userID] ?? "User")
                                                .foregroundColor(.barTabText)
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.barTabPrimary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        do {
            async let f = SupabaseClient.shared.fetchFollowing()
            async let m = SupabaseClient.shared.fetchGroupMembers(groupID: group.id)
            following = try await f
            members = Set((try await m).map(\.userID))

            for userID in following {
                if userCache[userID] == nil,
                   let profile = try? await SupabaseClient.shared.fetchProfile(userID: userID) {
                    userCache[userID] = profile.display_name ?? "User"
                    if let url = profile.avatar_url {
                        avatarCache[userID] = url
                    }
                }
            }
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func invite(_ userID: UUID) async {
        do {
            try await SupabaseClient.shared.inviteToGroup(groupID: group.id, userID: userID)
            members.insert(userID)
            HapticEngine.lightTap()
            toastCenter.show("Invited!", kind: .success)
        } catch {
            toastCenter.showError(error)
        }
    }
}
