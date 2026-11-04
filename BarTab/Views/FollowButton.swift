import SwiftUI

struct FollowButton: View {

    let userID: UUID
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var followStatus: SupabaseClient.FollowStatus = .none
    @State private var isLoading = false

    private var isSelf: Bool {
        userSession.currentUser?.id == userID
    }

    var body: some View {
        Group {
            if isSelf {
                EmptyView()
            } else if isLoading {
                ProgressView()
                    .frame(width: 80, height: 32)
            } else {
                switch followStatus {
                case .none:
                    Button {
                        Task { await sendRequest() }
                    } label: {
                        Text(String(localized: "Follow"))
                            .font(.BartapBody)
                            .fontWeight(.semibold)
                            .frame(width: 80, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color.BartapPrimary)
                    .foregroundColor(.white)
                    .clipShape(Capsule())

                case .pendingOutgoing:
                    Button {
                        Task { await cancelRequest() }
                    } label: {
                        Text(String(localized: "Requested"))
                            .font(.BartapBody)
                            .fontWeight(.semibold)
                            .frame(width: 80, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color.BartapPrimary.opacity(0.12))
                    .foregroundColor(.BartapPrimary)
                    .clipShape(Capsule())

                case .pendingIncoming:
                    HStack(spacing: 6) {
                        Button {
                            Task { await approveRequest() }
                        } label: {
                            Text(String(localized: "Accept"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .frame(width: 64, height: 32)
                        }
                        .buttonStyle(.plain)
                        .background(Color.BartapAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                        Button {
                            Task { await rejectRequest() }
                        } label: {
                            Text(String(localized: "Decline"))
                                .font(.BartapBody)
                                .fontWeight(.semibold)
                                .frame(width: 64, height: 32)
                        }
                        .buttonStyle(.plain)
                        .background(Color.BartapPrimary.opacity(0.12))
                        .foregroundColor(.BartapPrimary)
                        .clipShape(Capsule())
                    }

                case .accepted:
                    Button {
                        Task { await removeFollow() }
                    } label: {
                        Text(String(localized: "Following"))
                            .font(.BartapBody)
                            .fontWeight(.semibold)
                            .frame(width: 80, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color.BartapPrimary.opacity(0.12))
                    .foregroundColor(.BartapPrimary)
                    .clipShape(Capsule())
                }
            }
        }
        .onAppear {
            Task { await loadStatus() }
        }
    }

    private func loadStatus() async {
        guard let _ = userSession.currentUser?.id else { return }
        do {
            followStatus = try await SupabaseClient.shared.fetchFollowStatus(for: userID)
        } catch {
            toastCenter.showError(error)
        }
    }

    private func sendRequest() async {
        isLoading = true
        do {
            try await SupabaseClient.shared.sendFollowRequest(userID)
            followStatus = .pendingOutgoing
            HapticEngine.lightTap()
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func cancelRequest() async {
        isLoading = true
        do {
            try await SupabaseClient.shared.cancelFollowRequest(userID)
            followStatus = .none
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func approveRequest() async {
        isLoading = true
        do {
            try await SupabaseClient.shared.approveFollowRequest(userID)
            followStatus = .accepted
            HapticEngine.lightTap()
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func rejectRequest() async {
        isLoading = true
        do {
            try await SupabaseClient.shared.rejectFollowRequest(userID)
            followStatus = .none
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func removeFollow() async {
        isLoading = true
        do {
            try await SupabaseClient.shared.removeFollow(userID)
            followStatus = .none
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }
}
