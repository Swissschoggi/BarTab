import SwiftUI

struct FollowRequestsView: View {

    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var requests: [Follow] = []
    @State private var profiles: [UUID: ProfileDTO] = [:]
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BartapScreenHeader(
                    title: String(localized: "Follow Requests"),
                    subtitle: String(localized: "People who want to follow you.")
                )

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if requests.isEmpty {
                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "person.badge.plus")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)

                        Text(String(localized: "No pending requests"))
                            .font(.BartapHeading)

                        Text(String(localized: "When someone follows you, their request will appear here."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()
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
                    .BartapCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
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
                    .font(.BartapBody)
                    .fontWeight(.medium)
                    .foregroundColor(.BartapText)

                Text(String(localized: "wants to follow you"))
                    .font(.BartapSmall)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    Task { await approve(request: request) }
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
                    Task { await reject(request: request) }
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
        }
        .padding(.horizontal, BartapSpacing.sm)
        .padding(.vertical, BartapSpacing.sm)
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
