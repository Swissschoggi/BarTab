import SwiftUI

/// A single "night out" in a group: title, optional date, the shared
/// crawl (ordered bars), and who's going with an "I'm going" toggle.
struct NightOutCard: View {

    let event: GroupEvent
    let onDelete: () -> Void

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var stops: [CrawlStop] = []
    @State private var rsvps: [EventRSVP] = []
    @State private var rsvpProfiles: [UUID: ProfileAvatarRow] = [:]
    @State private var isTogglingRSVP = false

    private var isGoing: Bool {
        guard let userID = userSession.currentUser?.id else { return false }
        return rsvps.contains { $0.userID == userID }
    }

    private var isCreator: Bool {
        userSession.currentUser?.id == event.createdBy
    }

    private var orderedBars: [Bar] {
        stops
            .sorted { $0.position < $1.position }
            .compactMap { barRepository.getBar(id: $0.barID) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
            HStack(alignment: .top, spacing: BarTabSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.barTabHeading)
                        .foregroundColor(.barTabText)

                    if let startsAt = event.startsAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.barTabTiny)
                            Text(startsAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(.barTabSmall)
                        .foregroundColor(.barTabSecondary)
                    }
                }

                Spacer()

                goingButton

                if isCreator {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.barTabSmall)
                            .foregroundColor(.barTabDanger)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Shared crawl
            if !orderedBars.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "The crawl"))
                        .font(.barTabTiny)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabSecondary)

                    ForEach(Array(orderedBars.enumerated()), id: \.element.id) { index, bar in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.barTabTiny)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.barTabPrimary)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 1) {
                                Text(bar.name)
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabText)
                                Text(bar.address)
                                    .font(.barTabTiny)
                                    .foregroundColor(.barTabSecondary)
                            }
                        }
                    }
                }
                .padding(BarTabSpacing.sm)
                .background(Color.barTabSurface)
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))
            }

            // Who's going
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(rsvps.prefix(5), id: \.userID) { rsvp in
                        let profile = rsvpProfiles[rsvp.userID]
                        UserAvatarView(
                            urlString: profile?.avatarURL,
                            displayName: profile?.displayName ?? "U",
                            size: 22
                        )
                        .overlay(Circle().stroke(Color.barTabCardFill, lineWidth: 1))
                    }
                }

                Text(goingSummary)
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)
            }
        }
        .padding(14)
        .barTabCard()
        .task {
            await load()
        }
    }

    private var goingButton: some View {
        Button {
            Task { await toggleRSVP() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isGoing ? "checkmark.circle.fill" : "circle")
                    .font(.barTabSmall)
                Text(isGoing ? String(localized: "Going") : String(localized: "I'm going"))
                    .font(.barTabSmall)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isGoing ? .white : .barTabPrimary)
            .padding(.horizontal, BarTabSpacing.sm)
            .padding(.vertical, 6)
            .background(isGoing ? Color.barTabSuccess : Color.barTabPrimary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isTogglingRSVP)
    }

    private var goingSummary: String {
        let count = rsvps.count
        if count == 0 { return String(localized: "No one yet") }
        if count == 1 { return String(localized: "1 going") }
        return String(localized: "\(count) going")
    }

    private func load() async {
        do {
            async let s = SupabaseClient.shared.fetchCrawlStops(eventID: event.id)
            async let r = SupabaseClient.shared.fetchRSVPs(eventID: event.id)
            stops = try await s
            rsvps = try await r

            let ids = rsvps.map(\.userID)
            if !ids.isEmpty,
               let profiles = try? await SupabaseClient.shared.fetchProfileAvatarsByIDs(ids) {
                rsvpProfiles = profiles
            }
        } catch {
            toastCenter.showError(error)
        }
    }

    private func toggleRSVP() async {
        isTogglingRSVP = true
        defer { isTogglingRSVP = false }

        do {
            if isGoing {
                try await SupabaseClient.shared.unrsvp(eventID: event.id)
                if let userID = userSession.currentUser?.id {
                    rsvps.removeAll { $0.userID == userID }
                }
            } else {
                try await SupabaseClient.shared.rsvp(eventID: event.id)
                rsvps = try await SupabaseClient.shared.fetchRSVPs(eventID: event.id)
            }
            HapticEngine.lightTap()
        } catch {
            toastCenter.showError(error)
        }
    }
}
