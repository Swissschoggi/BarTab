import SwiftUI

struct GroupDetailView: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var members: [GroupMember] = []
    @State private var polls: [Poll] = []
    @State private var events: [GroupEvent] = []
    @State private var showingNewPoll = false
    @State private var showingNewEvent = false
    @State private var showingInvite = false
    @State private var isLoading = true
    @State private var shareItems: [Any] = []

    @State private var showingLeaveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingClosePoll: Poll?
    @State private var pendingDeleteEvent: GroupEvent?

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
                                Text(String(localized: "Members"))
                                    .font(.BartapHeading)
                                Spacer()
                                Button {
                                    showingInvite = true
                                } label: {
                                    Image(systemName: "person.badge.plus")
                                        .font(.BartapBody)
                                        .foregroundColor(.BartapPrimary)
                                }
                                Button {
                                    shareGroup()
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.BartapBody)
                                        .foregroundColor(.BartapPrimary)
                                }
                            }

                            FlowLayout(spacing: 8) {
                                ForEach(members) { member in
                                    HStack(spacing: 4) {
                                        UserAvatarView(urlString: avatarCache[member.userID], displayName: userCache[member.userID], size: 20)
                                        Text(memberLabel(member))
                                            .font(.BartapSmall)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, BartapSpacing.sm)
                                    .padding(.vertical, 5)
                                    .background(Color.BartapPrimary.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .BartapCard()

                        // Nights out section header
                        HStack {
                            Text(String(localized: "Nights out"))
                                .font(.BartapHeading)
                            Spacer()
                            Button {
                                showingNewEvent = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text(String(localized: "Plan"))
                                        .fontWeight(.semibold)
                                }
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            }
                        }

                        if events.isEmpty {
                            VStack(spacing: BartapSpacing.sm) {
                                Image(systemName: "figure.walk.circle")
                                    .font(.BartapEmptyIcon)
                                    .foregroundColor(.BartapPrimary)
                                Text(String(localized: "No nights out yet"))
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .BartapCard()
                        } else {
                            ForEach(events) { event in
                                NightOutCard(event: event, onDelete: {
                                    pendingDeleteEvent = event
                                })
                                    .environmentObject(barRepository)
                                    .environmentObject(userSession)
                                    .environmentObject(toastCenter)
                            }
                        }

                        // Polls section header
                        HStack {
                            Text(String(localized: "Polls"))
                                .font(.BartapHeading)
                            Spacer()
                            Button {
                                showingNewPoll = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text(String(localized: "New Poll"))
                                        .fontWeight(.semibold)
                                }
                                .font(.BartapBody)
                                .foregroundColor(.BartapPrimary)
                            }
                        }

                        if polls.isEmpty {
                            VStack(spacing: BartapSpacing.sm) {
                                Image(systemName: "checkmark.circle")
                                    .font(.BartapEmptyIcon)
                                    .foregroundColor(.BartapPrimary)
                                Text(String(localized: "No polls yet"))
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .BartapCard()
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
                        VStack(spacing: BartapSpacing.sm) {
                            Button {
                                showingLeaveConfirmation = true
                            } label: {
                                Label(String(localized: "Leave Group"), systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 12)
                            .background(Color.BartapDanger.opacity(0.08))
                            .foregroundColor(.BartapDanger)
                            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))

                            if isAdmin {
                                Button {
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label(String(localized: "Delete Group"), systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 12)
                                .background(Color.BartapDanger.opacity(0.15))
                                .foregroundColor(.BartapDanger)
                                .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .background(Color.BartapBackground.ignoresSafeArea())
                .navigationTitle(group.name)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingNewPoll) {
                    CreatePollSheet(group: group)
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }
                .sheet(isPresented: $showingNewEvent) {
                    PlanNightOutSheet(group: group)
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                        .environmentObject(locationService)
                }
                .onChange(of: showingNewEvent) { isPresented in
                    if !isPresented {
                        Task { await loadEvents() }
                    }
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
                .confirmationDialog(String(localized: "Leave this group?"), isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                    Button(String(localized: "Leave"), role: .destructive) {
                        Task { await leaveGroup() }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "You won't be able to see this group's polls anymore."))
                }
                .confirmationDialog(String(localized: "Delete this group?"), isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                    Button(String(localized: "Delete"), role: .destructive) {
                        Task { await deleteGroup() }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "All polls will be lost. This can't be undone."))
                }
                .confirmationDialog(String(localized: "Close this poll?"), isPresented: Binding(
                    get: { pendingClosePoll != nil },
                    set: { if !$0 { pendingClosePoll = nil } }
                ), titleVisibility: .visible) {
                    Button(String(localized: "Close Poll"), role: .destructive) {
                        if let poll = pendingClosePoll {
                            Task { await closePoll(poll) }
                        }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "No more votes will be accepted."))
                }
                .confirmationDialog(String(localized: "Delete this night out?"), isPresented: Binding(
                    get: { pendingDeleteEvent != nil },
                    set: { if !$0 { pendingDeleteEvent = nil } }
                ), titleVisibility: .visible) {
                    Button(String(localized: "Delete"), role: .destructive) {
                        if let event = pendingDeleteEvent {
                            Task { await deleteEvent(event) }
                        }
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "The crawl and RSVPs will be lost."))
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
        await loadEvents()

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

    private func loadEvents() async {
        do {
            events = try await SupabaseClient.shared.fetchEvents(groupID: group.id)
        } catch {
            toastCenter.showError(error)
        }
    }

    private func deleteEvent(_ event: GroupEvent) async {
        do {
            try await SupabaseClient.shared.deleteEvent(event.id)
            events.removeAll { $0.id == event.id }
            HapticEngine.lightTap()
            pendingDeleteEvent = nil
        } catch {
            toastCenter.showError(error)
        }
    }

    private func leaveGroup() async {
        do {
            try await SupabaseClient.shared.leaveGroup(groupID: group.id)
            toastCenter.show(String(localized: "Left group"), kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
    }

    private func deleteGroup() async {
        do {
            try await SupabaseClient.shared.deleteGroup(groupID: group.id)
            toastCenter.show(String(localized: "Group deleted"), kind: .success)
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
        let shareText = "Join my group \"\(group.name)\" on Bartap! 🍺"
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
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {
            HStack {
                Text(poll.title)
                    .font(.BartapHeading)
                Spacer()
                if isOpen {
                    Text(String(localized: "Active"))
                        .font(.BartapTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.BartapSuccess)
                        .clipShape(Capsule())
                } else {
                    Text(String(localized: "Closed"))
                        .font(.BartapTiny)
                        .fontWeight(.bold)
                        .foregroundColor(.BartapSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.BartapSecondary.opacity(0.2))
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
                            .font(.BartapSmall)
                        Text(String(localized: "Close poll"))
                            .font(.BartapSmall)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.BartapDanger)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .BartapCard()
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
                HStack(spacing: BartapSpacing.sm) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selected ? .BartapPrimary : .BartapSecondary)

                    Text(option.label)
                        .font(.BartapBody)
                        .foregroundColor(.BartapText)

                    Spacer()

                    Text("\(voteCount)")
                        .font(.BartapSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.BartapAccent)
                }

                if let barID = option.barID,
                   let bar = barRepository.getBar(id: barID) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.BartapTiny)
                        Text(bar.name)
                            .font(.BartapTiny)
                            .foregroundColor(.BartapSecondary)
                    }
                    .padding(.leading, 26)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous)
                    .fill(selected ? Color.BartapPrimary.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous)
                            .stroke(selected ? Color.BartapPrimary.opacity(0.3) : Color.BartapCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
