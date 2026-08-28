import SwiftUI

struct InviteMemberSheet: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.presentationMode) private var presentationMode

    @State private var following: [UUID] = []
    @State private var members: Set<UUID> = []
    @State private var userCache: [UUID: String] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        let notInGroup = following.filter { !members.contains($0) }

                        if notInGroup.isEmpty {
                            Text("All your friends are already in this group.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(notInGroup, id: \.self) { userID in
                                Button {
                                    Task { await invite(userID) }
                                } label: {
                                    HStack {
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
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
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
                }
            }
        } catch {
            print("Failed to load members: \(error)")
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
