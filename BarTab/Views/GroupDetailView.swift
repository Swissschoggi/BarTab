import SwiftUI

struct GroupDetailView: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var members: [GroupMember] = []
    @State private var polls: [Poll] = []
    @State private var showingNewPoll = false
    @State private var showingInvite = false
    @State private var isLoading = true
    @State private var shareItems: [Any] = []

    @State private var showingLeaveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingClosePoll: Poll?

    private var isAdmin: Bool {
        guard let userID = userSession.currentUser?.id else { return false }
        return members.first { $0.userID == userID }?.isAdmin == true
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Members
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Members")
                                    .font(.barTabHeading)
                                Spacer()
                                Button {
                                    showingInvite = true
                                } label: {
                                    Image(systemName: "person.badge.plus")
                                        .font(.barTabBody)
                                        .foregroundColor(.barTabPrimary)
                                }
                                Button {
                                    shareGroup()
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.barTabBody)
                                        .foregroundColor(.barTabPrimary)
                                }
                            }

                            FlowLayout(spacing: 8) {
                                ForEach(members) { member in
                                    HStack(spacing: 4) {
                                        UserAvatarView(urlString: avatarCache[member.userID], displayName: userCache[member.userID], size: 20)
                                        Text(memberLabel(member))
                                            .font(.barTabSmall)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.barTabPrimary.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .barTabCard()

                        // Polls section header
                        HStack {
                            Text("Polls")
                                .font(.barTabHeading)
                            Spacer()
                            Button {
                                showingNewPoll = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("New Poll")
                                        .fontWeight(.semibold)
                                }
                                .font(.barTabBody)
                                .foregroundColor(.barTabPrimary)
                            }
                        }

                        if polls.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "checkmark.circle")
                                    .font(.barTabEmptyIcon)
                                    .foregroundColor(.barTabPrimary)
                                Text("No polls yet")
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .barTabCard()
                        } else {
                            ForEach(polls) { poll in
                                PollCard(poll: poll, isAdmin: isAdmin, onClose: {
                                    pendingClosePoll = poll
                                })
                                    .environmentObject(barRepository)
                                    .environmentObject(userSession)
                                    .environmentObject(toastCenter)
                            }
                        }

                        // Danger zone
                        VStack(spacing: 10) {
                            Button {
                                showingLeaveConfirmation = true
                            } label: {
                                Label("Leave Group", systemImage: "rectangle.right.and.line.left")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 12)
                            .background(Color.barTabDanger.opacity(0.08))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            if isAdmin {
                                Button {
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete Group", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 12)
                                .background(Color.barTabDanger.opacity(0.15))
                                .foregroundColor(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .background(Color.barTabBackground.ignoresSafeArea())
                .navigationTitle(group.name)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingNewPoll) {
                    CreatePollSheet(group: group)
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }
                .onChange(of: showingNewPoll) { isPresented in
                    if !isPresented {
                        Task { await loadPolls() }
                    }
                }
                .sheet(isPresented: $showingInvite) {
                    InviteMemberSheet(group: group)
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }
                .sheet(isPresented: Binding(
                    get: { !shareItems.isEmpty },
                    set: { if !$0 { shareItems = [] } }
                )) {
                    ShareSheet(items: shareItems)
                }
                .confirmationDialog("Leave this group?", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                    Button("Leave", role: .destructive) {
                        Task { await leaveGroup() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You won't be able to see this group's polls anymore.")
                }
                .confirmationDialog("Delete this group?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        Task { await deleteGroup() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All polls will be lost. This can't be undone.")
                }
                .confirmationDialog("Close this poll?", isPresented: Binding(
                    get: { pendingClosePoll != nil },
                    set: { if !$0 { pendingClosePoll = nil } }
                ), titleVisibility: .visible) {
                    Button("Close Poll", role: .destructive) {
                        if let poll = pendingClosePoll {
                            Task { await closePoll(poll) }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("No more votes will be accepted.")
                }
                .refreshable {
                    await loadData()
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func memberLabel(_ member: GroupMember) -> String {
        let name = userCache[member.userID] ?? "User"
        return member.isAdmin ? "\(name) ★" : name
    }

    @State private var userCache: [UUID: String] = [:]
    @State private var avatarCache: [UUID: String] = [:]

    private func loadData() async {
        do {
            let fetchedMembers = try await SupabaseClient.shared.fetchGroupMembers(groupID: group.id)
            members = fetchedMembers
        } catch {
            toastCenter.showError(error)
        }

        await loadPolls()

        let userIDs = members.map(\.userID)
        if !userIDs.isEmpty {
            if let profiles = try? await SupabaseClient.shared.fetchProfileAvatarsByIDs(userIDs) {
                for (id, profile) in profiles {
                    userCache[id] = profile.displayName ?? "User"
                    if let url = profile.avatarURL {
                        avatarCache[id] = url
                    }
                }
            }
        }

        isLoading = false
    }

    private func loadPolls() async {
        do {
            polls = try await SupabaseClient.shared.fetchPolls(groupID: group.id)
        } catch {
            toastCenter.showError(error)
        }
    }

    private func leaveGroup() async {
        do {
            try await SupabaseClient.shared.leaveGroup(groupID: group.id)
            toastCenter.show("Left group", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
    }

    private func deleteGroup() async {
        do {
            try await SupabaseClient.shared.deleteGroup(groupID: group.id)
            toastCenter.show("Group deleted", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
    }

    private func closePoll(_ poll: Poll) async {
        do {
            try await SupabaseClient.shared.closePoll(pollID: poll.id)
            if let index = polls.firstIndex(where: { $0.id == poll.id }) {
                polls[index] = Poll(
                    id: poll.id,
                    groupID: poll.groupID,
                    title: poll.title,
                    createdBy: poll.createdBy,
                    createdAt: poll.createdAt,
                    expiresAt: poll.expiresAt,
                    isClosed: true
                )
            }
            HapticEngine.lightTap()
            pendingClosePoll = nil
        } catch {
            toastCenter.showError(error)
        }
    }

    private func shareGroup() {
        let shareText = "Join my group \"\(group.name)\" on BarTab! 🍺"
        shareItems = [shareText, DeepLink.group(group.id)]
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Poll Card

struct PollCard: View {

    let poll: Poll
    let isAdmin: Bool
    let onClose: () -> Void

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var options: [PollOption] = []
    @State private var votes: [PollVote] = []
    @State private var myVote: UUID?
    @State private var userCache: [UUID: String] = [:]

    private var isOpen: Bool {
        !poll.isClosed
    }

    private var isPollCreator: Bool {
        userSession.currentUser?.id == poll.createdBy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(poll.title)
                    .font(.barTabHeading)
                Spacer()
                if isOpen {
                    Text("Active")
                        .font(.barTabTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.barTabSuccess)
                        .clipShape(Capsule())
                } else {
                    Text("Closed")
                        .font(.barTabTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.barTabSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.barTabSecondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            ForEach(options) { option in
                optionRow(option)
            }

            if isOpen && isPollCreator {
                Button {
                    onClose()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.barTabSmall)
                        Text("Close poll")
                            .font(.barTabSmall)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .barTabCard()
        .task {
            await loadPollData()
        }
    }

    private func loadPollData() async {
        do {
            async let o = SupabaseClient.shared.fetchPollOptions(pollID: poll.id)
            async let v = SupabaseClient.shared.fetchPollVotes(pollID: poll.id)
            options = try await o
            votes = try await v

            if let userID = userSession.currentUser?.id {
                myVote = votes.first(where: { $0.userID == userID })?.optionID
            }
        } catch {
            toastCenter.showError(error)
        }
    }

    private func vote(_ option: PollOption) async {
        do {
            try await SupabaseClient.shared.votePoll(pollID: poll.id, optionID: option.id)
            myVote = option.id
            votes = try await SupabaseClient.shared.fetchPollVotes(pollID: poll.id)
            HapticEngine.lightTap()
        } catch {
            toastCenter.showError(error)
        }
    }

    @ViewBuilder
    private func optionRow(_ option: PollOption) -> some View {
        let selected = myVote == option.id
        let voteCount = votes.filter { $0.optionID == option.id }.count

        Button {
            guard isOpen else { return }
            Task { await vote(option) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selected ? .barTabPrimary : .barTabSecondary)

                    Text(option.label)
                        .font(.barTabBody)
                        .foregroundColor(.barTabText)

                    Spacer()

                    Text("\(voteCount)")
                        .font(.barTabSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.barTabAccent)
                }

                if let barID = option.barID,
                   let bar = barRepository.getBar(id: barID) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.barTabTiny)
                        Text(bar.name)
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSecondary)
                    }
                    .padding(.leading, 26)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.barTabPrimary.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selected ? Color.barTabPrimary.opacity(0.3) : Color.barTabCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
