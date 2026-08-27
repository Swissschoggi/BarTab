import SwiftUI

struct FollowButton: View {

    let userID: UUID
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var isFollowing = false
    @State private var followerCount = 0
    @State private var isLoading = false

    private var isSelf: Bool {
        userSession.currentUser?.id == userID
    }

    var body: some View {
        Group {
            if isSelf {
                EmptyView()
            } else {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 80, height: 32)
                    } else {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(width: 80, height: 32)
                    }
                }
                .buttonStyle(.plain)
                .background(
                    isFollowing
                        ? Color.barTabPrimary.opacity(0.12)
                        : Color.barTabPrimary
                )
                .foregroundColor(isFollowing ? .barTabPrimary : .white)
                .clipShape(Capsule())
            }
        }
        .onAppear {
            Task { await loadState() }
        }
    }

    private func loadState() async {
        guard let myID = userSession.currentUser?.id else { return }
        do {
            let following = try await SupabaseClient.shared.fetchFollowing()
            isFollowing = following.contains(userID)
            followerCount = try await SupabaseClient.shared.fetchFollowerCount(for: userID)
        } catch {
            print("Failed to load follow state: \(error)")
        }
    }

    private func toggleFollow() async {
        isLoading = true
        do {
            if isFollowing {
                try await SupabaseClient.shared.unfollow(userID)
                isFollowing = false
                followerCount = max(0, followerCount - 1)
            } else {
                try await SupabaseClient.shared.follow(userID)
                isFollowing = true
                followerCount += 1
                HapticEngine.lightTap()
            }
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }
}
