import SwiftUI

struct GroupDetailView: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var members: [GroupMember] = []
    @State private var polls: [Poll] = []
    @State private var showingNewPoll = false
    @State private var showingInvite = false
    @State private var isLoading = true

    var body: some View {
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

                // New poll button
                Button {
                    showingNewPoll = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("New Poll")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, height: 44)
                }
                .barTabPrimaryButton()

                // Polls
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
                        PollCard(poll: poll)
                            .environmentObject(barRepository)
                            .environmentObject(userSession)
                            .environmentObject(toastCenter)
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
        .task {
            await loadData()
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

            for member in members {
                if userCache[member.userID] == nil,
                    let profile = try? await SupabaseClient.shared.fetchProfile(userID: member.userID) {
                    userCache[member.userID] = profile.display_name ?? "User"
                }
            }
        } catch {
            print("Failed to load group data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Poll Card

struct PollCard: View {

    let poll: Poll

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
            print("Failed to load poll data: \(error)")
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
