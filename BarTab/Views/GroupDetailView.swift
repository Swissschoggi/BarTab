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
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showingInvite = true
                                } label: {
                                    Image(systemName: "person.badge.plus")
                                        .font(.subheadline)
                                        .foregroundColor(.barTabPrimary)
                                }
                            }

                            FlowLayout(spacing: 8) {
                                ForEach(members) { member in
                                    Text(memberLabel(member))
                                        .font(.caption)
                                        .fontWeight(.medium)
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
                                .font(.headline)
                            Spacer()
                            Button {
                                showingNewPoll = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("New Poll")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .foregroundColor(.barTabPrimary)
                            }
                        }

                        if polls.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 36))
                                    .foregroundColor(.barTabPrimary)
                                Text("No polls yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                            .background(Color.red.opacity(0.08))
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
                                .background(Color.red.opacity(0.15))
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
                .sheet(isPresented: $showingInvite) {
                    InviteMemberSheet(group: group)
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
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
                .task {
                    await loadData()
                }
            }
        }
    }

    private func memberLabel(_ member: GroupMember) -> String {
        let name = userCache[member.userID] ?? "User"
        return member.isAdmin ? "\(name) ★" : name
    }

    @State private var userCache: [UUID: String] = [:]

    private func loadData() async {
        do {
            async let m = SupabaseClient.shared.fetchGroupMembers(groupID: group.id)
            async let p = SupabaseClient.shared.fetchPolls(groupID: group.id)
            members = try await m
            polls = try await p

            let userIDs = members.map(\.userID)
            userCache = try await SupabaseClient.shared.fetchProfileNamesByIDs(userIDs)
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
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
                    .font(.headline)
                Spacer()
                if isOpen {
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.barTabSuccess)
                        .clipShape(Capsule())
                } else {
                    Text("Closed")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            ForEach(options) { option in
                let voteCount = votes.filter { $0.optionID == option.id }.count
                let isSelected = myVote == option.id

                Button {
                    guard isOpen else { return }
                    Task { await vote(option) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .barTabPrimary : .barTabSecondary)

                            Text(option.label)
                                .font(.subheadline)
                                .foregroundColor(.barTabText)

                            Spacer()

                            Text("\(voteCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.barTabAccent)
                        }

                        if let barID = option.barID,
                           let bar = barRepository.getBar(id: barID) {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption2)
                                Text(bar.name)
                                    .font(.caption2)
                                    .foregroundColor(.barTabSecondary)
                            }
                            .padding(.leading, 26)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? Color.barTabPrimary.opacity(0.08) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? Color.barTabPrimary.opacity(0.3) : Color.barTabCardBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            if isOpen && isPollCreator {
                Button {
                    onClose()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                        Text("Close poll")
                            .font(.caption)
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
}
