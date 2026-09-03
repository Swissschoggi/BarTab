import SwiftUI

struct FollowRequestsView: View {

    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var requests: [Follow] = []
    @State private var profiles: [UUID: ProfileDTO] = [:]
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BarTabScreenHeader(
                    title: String(localized: "Follow Requests"),
                    subtitle: String(localized: "People who want to follow you.")
                )

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if requests.isEmpty {
                    VStack(spacing: BarTabSpacing.sm) {
                        Image(systemName: "person.badge.plus")
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)

                        Text(String(localized: "No pending requests"))
                            .font(.barTabHeading)

                        Text(String(localized: "When someone follows you, their request will appear here."))
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                            requestRow(request)
                            if index < requests.count - 1 {
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
        .navigationTitle(String(localized: "Follow Requests"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRequests() }
    }

    private func requestRow(_ request: Follow) -> some View {
        let senderID = request.followerID ?? UUID()
        let profile = profiles[senderID]

        return HStack(spacing: 12) {
            UserAvatarView(urlString: profile?.avatar_url, displayName: profile?.display_name)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.display_name ?? String(localized: "User"))
                    .font(.barTabBody)
                    .fontWeight(.medium)
                    .foregroundColor(.barTabText)

                Text(String(localized: "wants to follow you"))
                    .font(.barTabSmall)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    Task { await approve(request: request) }
                } label: {
                    Text(String(localized: "Accept"))
                        .font(.barTabBody)
                        .fontWeight(.semibold)
                        .frame(width: 64, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.barTabAccent)
                .foregroundColor(.white)
                .clipShape(Capsule())

                Button {
                    Task { await reject(request: request) }
                } label: {
                    Text(String(localized: "Decline"))
                        .font(.barTabBody)
                        .fontWeight(.semibold)
                        .frame(width: 64, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.barTabPrimary.opacity(0.12))
                .foregroundColor(.barTabPrimary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, BarTabSpacing.sm)
        .padding(.vertical, BarTabSpacing.sm)
    }

    private func loadRequests() async {
        do {
            requests = try await SupabaseClient.shared.fetchIncomingFollowRequests()
            let senderIDs = requests.compactMap(\.followerID)
            profiles = try await SupabaseClient.shared.fetchProfilesByIDs(senderIDs)
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }

    private func approve(request: Follow) async {
        guard let senderID = request.followerID else { return }
        do {
            try await SupabaseClient.shared.approveFollowRequest(senderID)
            requests.removeAll { $0.followerID == senderID }
            HapticEngine.lightTap()
        } catch {
            toastCenter.showError(error)
        }
    }

    private func reject(request: Follow) async {
        guard let senderID = request.followerID else { return }
        do {
            try await SupabaseClient.shared.rejectFollowRequest(senderID)
            requests.removeAll { $0.followerID == senderID }
        } catch {
            toastCenter.showError(error)
        }
    }
}
