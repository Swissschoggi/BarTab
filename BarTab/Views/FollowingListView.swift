import SwiftUI

struct FollowingListView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var barRepository: BarRepository
    @Environment(\.dismiss) private var dismiss

    @State private var followingIDs: [UUID] = []
    @State private var profiles: [UUID: ProfileDTO] = [:]
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if followingIDs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.barTabPrimary)
                    Text("Not following anyone yet")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Find friends to see their drink reports here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .barTabCard()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(followingIDs, id: \.self) { userID in
                            if let profile = profiles[userID] {
                                followingRow(profile: profile)
                                if userID != followingIDs.last {
                                    Divider()
                                        .foregroundColor(.barTabCardBorder)
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                    .barTabCard()
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func followingRow(profile: ProfileDTO) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.barTabPrimary)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.display_name ?? "User")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabText)
            }

            Spacer()

            Button {
                Task { await unfollow(profile) }
            } label: {
                Text("Unfollow")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadData() async {
        guard let userID = userSession.currentUser?.id else { return }
        do {
            followingIDs = try await SupabaseClient.shared.fetchFollowing()
            if !followingIDs.isEmpty {
                profiles = try await SupabaseClient.shared.fetchProfilesByIDs(followingIDs)
            }
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func unfollow(_ profile: ProfileDTO) async {
        do {
            try await SupabaseClient.shared.removeFollow(profile.id)
            followingIDs.removeAll { $0 == profile.id }
            profiles.removeValue(forKey: profile.id)
            toastCenter.show("Unfollowed \(profile.display_name ?? "user")", kind: .success)
        } catch {
            toastCenter.showError(error)
        }
    }
}
