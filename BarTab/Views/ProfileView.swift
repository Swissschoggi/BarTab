import SwiftUI
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var showingLogin = false
    @State private var showingSettings = false
    @State private var showingLeaderboard = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var showingLogoutConfirmation = false

    private var currentUser: User? {
        userSession.currentUser
    }

    private var unreviewedReportCount: Int {
        barRepository.unreviewedReportCount
    }

    private var totalContributions: Int {
        guard currentUser != nil else { return 0 }
        let prices = myPrices.count
        let bars = myBars.count
        return prices + bars
    }

    private var currentLevel: UserLevel {
        .current(for: totalContributions)
    }

    private var myBars: [Bar] {
        guard let user = currentUser else {
            return []
        }

        return barRepository.getBars().filter {
            $0.createdBy == user.id
        }
    }

    private var myPrices: [(bar: Bar, price: Price)] {
        guard let user = currentUser else {
            return []
        }

        var results: [(bar: Bar, price: Price)] = []

        for bar in barRepository.getBars() {
            for price in barRepository.getPrices(for: bar) {
                if price.reportedBy == user.id {
                    results.append(
                        (
                            bar: bar,
                            price: price
                        )
                    )
                }
            }
        }

        return results
    }

    var body: some View {
        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    headerSection

                    if let user = currentUser {

                        profileCard(user: user)
                        activitySection
                        savedSection
                        socialSection
                        adminSection
                        accountSection

                    } else {
                        signedOutSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, BartapSpacing.xxl)
                .padding(.bottom, BartapSpacing.xl)
            }
            .background(
                Color.BartapBackground
                    .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .refreshable {
            await barRepository.fetchAllData()
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(userSession)
                .environmentObject(barRepository)
                .environmentObject(LanguageManager.shared)
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
                .environmentObject(barRepository)
                .environmentObject(userSession)
        }
        .confirmationDialog(
            String(localized: "Log out?"),
            isPresented: $showingLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Log out"), role: .destructive) {
                HapticEngine.impact()
                withAnimation(.easeInOut(duration: 0.3)) {
                    userSession.logout()
                }
                toastCenter.show(
                    String(localized: "You've been logged out."),
                    kind: .info
                )
            }

            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "You'll need to sign in again to add bars, prices and ratings."))
        }
        .onChange(of: selectedAvatarItem) { item in
            guard let item else { return }
            selectedAvatarItem = nil
            uploadAvatar(from: item)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {

            BartapScreenHeader(
                title: String(localized: "Me"),
                subtitle: currentUser == nil
                    ? String(localized: "Sign in to manage your contributions.")
                    : String(localized: "Your Bartap profile.")
            )

            if let fetchedAt = barRepository.lastFetchedAt {
                Text("Data updated \(fetchedAt.relativeFormatted)")
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func profileCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {

            HStack(spacing: BartapSpacing.sm) {

                avatarView(user: user)

                VStack(alignment: .leading, spacing: 2) {

                    Text(user.username)
                        .font(.BartapHeading)
                        .fontWeight(.bold)
                        .foregroundColor(.BartapText)

                    Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)

                    PhotosPicker(
                        selection: $selectedAvatarItem,
                        matching: .images
                    ) {
                        Text(isUploadingAvatar ? String(localized: "Uploading…") : String(localized: "Change photo"))
                            .font(.BartapSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.BartapPrimary)
                    }
                    .disabled(isUploadingAvatar)
                }

                Spacer()
            }

            Divider()
                .foregroundColor(.BartapCardBorder)

            // Level + progress
            HStack(spacing: 12) {
                Image(systemName: currentLevel.icon)
                    .font(.BartapBody)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.BartapAccent)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentLevel.name)
                        .font(.BartapBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.BartapText)

                    if let remaining = UserLevel.remaining(for: totalContributions) {
                        Text("\(remaining) more to next level")
                            .font(.BartapTiny)
                            .foregroundColor(.BartapSecondary)
                    } else {
                        Text(String(localized: "Max level reached!"))
                            .font(.BartapTiny)
                            .foregroundColor(.BartapAccent)
                    }
                }

                Spacer()

                Text("\(totalContributions)")
                    .font(.BartapHeading)
                    .fontWeight(.bold)
                    .foregroundColor(.BartapAccent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.BartapPillFill)

                    Capsule()
                        .fill(Color.BartapAccent)
                        .frame(width: geometry.size.width * CGFloat(UserLevel.progress(for: totalContributions)))
                }
            }
            .frame(height: 5)
        }
        .BartapCard()
    }

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {

            Text(String(localized: "Your activity"))
                .font(.BartapHeading)

            HStack(spacing: BartapSpacing.sm) {
                statisticCard(
                    value: myPrices.count,
                    title: String(localized: "Drinks"),
                    icon: "mug.fill"
                )

                statisticCard(
                    value: myBars.count,
                    title: String(localized: "Bars"),
                    icon: "building.2.fill"
                )
            }

            VStack(spacing: 0) {
                navigationRow(
                    title: String(localized: "My drinks"),
                    subtitle: "\(myPrices.count) contributions",
                    icon: "tag.fill"
                ) {
                    MyContributionsView()
                }

                Divider()
                    .foregroundColor(.BartapCardBorder)
                    .padding(.leading, BartapSpacing.md)

                navigationRow(
                    title: String(localized: "My bars"),
                    subtitle: "\(myBars.count) bars added",
                    icon: "building.2.fill"
                ) {
                    MyBarsView()
                }

                Divider()
                    .foregroundColor(.BartapCardBorder)
                    .padding(.leading, BartapSpacing.md)

                navigationRow(
                    title: String(localized: "Badges"),
                    subtitle: String(localized: "Your achievements"),
                    icon: "rosette"
                ) {
                    BadgeGridView(
                        earnedBadges: BadgeService.shared.earnedBadges(),
                        allBadges: BadgeService.shared.allBadges(),
                        streak: BadgeService.shared.currentStreak
                    )
                }

                Divider()
                    .foregroundColor(.BartapCardBorder)
                    .padding(.leading, BartapSpacing.md)

                navigationRow(
                    title: String(localized: "Passport"),
                    subtitle: String(localized: "Bars you've visited"),
                    icon: "book.closed.fill"
                ) {
                    PassportView()
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }
            }
            .BartapCard()
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {
            Text(String(localized: "Saved"))
                .font(.BartapHeading)

            VStack(spacing: 0) {
                if !barRepository.favoriteBars.isEmpty {
                    ForEach(barRepository.favoriteBars) { bar in
                        navigationRow(
                            title: bar.name,
                            subtitle: bar.address,
                            icon: "heart.fill"
                        ) {
                            BarView(bar: bar)
                                .environmentObject(barRepository)
                                .environmentObject(userSession)
                        }

                        Divider()
                            .foregroundColor(.BartapCardBorder)
                            .padding(.leading, BartapSpacing.md)
                    }
                }

                navigationRow(
                    title: String(localized: "Price Alerts"),
                    subtitle: String(localized: "Get notified on price changes"),
                    icon: "bell.fill"
                ) {
                    PriceAlertListView()
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }
            }
            .BartapCard()
        }
    }

    @ViewBuilder
    private var adminSection: some View {
        if let user = currentUser, user.isAdmin {

            VStack(alignment: .leading, spacing: BartapSpacing.sm) {

                Text(String(localized: "Admin"))
                    .font(.BartapHeading)

                navigationRow(
                    title: String(localized: "Reported content"),
                    subtitle: unreviewedReportCount == 0
                        ? String(localized: "Nothing to review")
                        : "\(unreviewedReportCount) "
                        + "\(unreviewedReportCount == 1 ? "report" : "reports") to review",
                    icon: "flag.fill"
                ) {
                    AdminReportsView()
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }

                navigationRow(
                    title: String(localized: "Brand requests"),
                    subtitle: barRepository.pendingBrandRequestCount == 0
                        ? String(localized: "Nothing to review")
                        : "\(barRepository.pendingBrandRequestCount) "
                        + "\(barRepository.pendingBrandRequestCount == 1 ? "request" : "requests") to review",
                    icon: "tag.fill"
                ) {
                    AdminBrandRequestsView()
                }
            }
        }
    }

    @ViewBuilder
    private var socialSection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {
            Text(String(localized: "Social"))
                .font(.BartapHeading)

            socialRows
        }
    }

    @ViewBuilder
    private var socialRows: some View {
        VStack(spacing: 0) {
            navigationRow(
                title: String(localized: "Friends"),
                subtitle: String(localized: "Find people, requests and following"),
                icon: "person.2.fill"
            ) {
                FriendsView()
            }

            Divider()
                .foregroundColor(.BartapCardBorder)
                .padding(.leading, BartapSpacing.md)

            navigationRow(
                title: String(localized: "Activity"),
                subtitle: String(localized: "See what friends are drinking"),
                icon: "list.bullet.rectangle"
            ) {
                ActivityFeedView()
            }

            Divider()
                .foregroundColor(.BartapCardBorder)
                .padding(.leading, BartapSpacing.md)

            navigationRow(
                title: String(localized: "Groups"),
                subtitle: String(localized: "Plan nights out"),
                icon: "person.3.fill"
            ) {
                GroupPlanningView()
            }
        }
        .BartapCard()
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {

            Text(String(localized: "Account"))
                .font(.BartapHeading)

            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.BartapPrimary)

                    Text(String(localized: "Settings"))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.BartapSmall)
                        .foregroundColor(.secondary)
                }
                .BartapCard()
            }

            Button {
                showingLeaderboard = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.BartapAccent)

                    Text(String(localized: "Leaderboard"))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.BartapSmall)
                        .foregroundColor(.secondary)
                }
                .BartapCard()
            }

            Button {
                showingLogoutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.BartapDanger)

                    Text(String(localized: "Log out"))
                        .foregroundColor(.BartapDanger)

                    Spacer()
                }
                .BartapCard()
            }
        }
    }

    @ViewBuilder
    private var signedOutSection: some View {
        VStack(spacing: 16) {

            Image(systemName: "person.crop.circle")
                .font(.BartapEmptyIconLarge)
                .foregroundColor(.BartapPrimary)

            Text(String(localized: "You're not signed in"))
                .font(.BartapHeading)
                .fontWeight(.semibold)

            Text(String(localized: "Sign in to add bars, report drinks and keep track of your contributions."))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button {
                showingLogin = true
            } label: {
                Text(String(localized: "Sign In"))
                    .font(.BartapHeading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .BartapPrimaryButton()
            }
        }
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func avatarView(user: User) -> some View {

        ZStack {
            if let url = user.avatarURL,
               !isUploadingAvatar {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderAvatar
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                placeholderAvatar
                    .opacity(isUploadingAvatar ? 0.5 : 1)

                if isUploadingAvatar {
                    ProgressView()
                }
            }
        }
        .frame(width: 48, height: 48)
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.BartapPrimary)

            Image(systemName: "person.fill")
                .font(.BartapHeading)
                .foregroundColor(.white)
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem) {
        Task { @MainActor in
            isUploadingAvatar = true

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    isUploadingAvatar = false
                    toastCenter.show(String(localized: "That photo couldn't be loaded."), kind: .error)
                    return
                }

                try await userSession.updateAvatar(image: image)
                isUploadingAvatar = false
                toastCenter.show(String(localized: "Profile photo updated"), kind: .success)
            } catch {
                isUploadingAvatar = false
                toastCenter.showError(error)
            }
        }
    }

    private func statisticCard(
        value: Int,
        title: String,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Image(systemName: icon)
                .font(.BartapBody)
                .foregroundColor(.BartapPrimary)
                .frame(width: 28, height: 28)
                .background(Color.BartapPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))

            Text("\(value)")
                .font(.BartapHeading)
                .fontWeight(.bold)
                .foregroundColor(.BartapText)

            Text(title)
                .font(.BartapSmall)
                .foregroundColor(.BartapSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .BartapCard()
    }

    private func navigationRow<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {

        NavigationLink {
            destination()
        } label: {

            HStack(spacing: 12) {

                Image(systemName: icon)
                    .font(.BartapBody)
                    .foregroundColor(.BartapPrimary)
                    .frame(width: 24, height: 24)
                    .background(Color.BartapPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {

                    Text(title)
                        .font(.BartapBody)
                        .fontWeight(.medium)
                        .foregroundColor(.BartapText)

                    Text(subtitle)
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)
            }
            .BartapCard()
        }
    }
}

/// Combines find-friends, follow requests and following into one screen.
struct FriendsView: View {

    private enum Tab: String, CaseIterable {
        case find = "Find"
        case requests = "Requests"
        case here = "Here now"
        case following = "Following"
    }

    @State private var tab: Tab = .find

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Tab"), selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch tab {
            case .find:
                FindUsersView()
            case .requests:
                FollowRequestsView()
            case .here:
                HereNowView()
            case .following:
                FollowingListView()
            }
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Friends"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.BartapBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// Shows which of your friends are currently checked in at a bar,
/// grouped by bar and ordered by distance from you.
struct HereNowView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var followingIDs: Set<UUID> = []
    @State private var profiles: [UUID: ProfileDTO] = [:]
    @State private var isLoading = true
    @State private var selectedBar: Bar?

    private struct FriendPresence: Identifiable {
        let bar: Bar
        let profiles: [ProfileDTO]
        var id: UUID { bar.id }
    }

    private var presence: [FriendPresence] {
        var byBar: [UUID: [ProfileDTO]] = [:]

        for checkin in barRepository.freshCheckins() {
            guard followingIDs.contains(checkin.userID),
                  let bar = barRepository.getBar(id: checkin.barID),
                  let profile = profiles[checkin.userID] else { continue }
            byBar[bar.id, default: []].append(profile)
        }

        return byBar.compactMap { barID, people in
            guard let bar = barRepository.getBar(id: barID) else { return nil }
            return FriendPresence(bar: bar, profiles: people)
        }
        .sorted { lhs, rhs in
            guard let location = locationService.location else {
                return lhs.profiles.count > rhs.profiles.count
            }
            return DistanceService.distance(from: location, to: lhs.bar)
                < DistanceService.distance(from: location, to: rhs.bar)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                    HStack {
                        Text(String(localized: "OUT NOW"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, BartapSpacing.md)

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(String(localized: "Checking who's out…"))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, BartapSpacing.md)
                        .padding(.vertical, BartapSpacing.xs)
                    } else if presence.isEmpty {
                        emptyState(minHeight: geo.size.height - 68)
                    } else {
                        presenceList(minHeight: geo.size.height - 68)
                    }
                }
                .padding(.vertical, BartapSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Here now"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .sheet(item: $selectedBar) { bar in
            NavigationStack {
                BarView(bar: bar, allowsDismissal: true)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
                    .environmentObject(locationService)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func emptyState(minHeight: CGFloat) -> some View {
        VStack(spacing: BartapSpacing.sm) {
            Image(systemName: "figure.walk")
                .font(.BartapEmptyIcon)
                .foregroundColor(.BartapPrimary)

            Text(String(localized: "Nobody's out right now"))
                .font(.BartapBody)
                .fontWeight(.medium)

            Text(String(localized: "When friends check in at a bar, they'll show up here."))
                .font(.BartapSmall)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 36)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                .fill(Color.BartapCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                .stroke(Color.BartapCardBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, BartapSpacing.md)
    }

    private func presenceList(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(presence) { group in
                presenceRow(group)
                if group.id != presence.last?.id {
                    Divider()
                        .foregroundColor(.BartapCardBorder)
                        .padding(.leading, 68)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                .fill(Color.BartapCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                .stroke(Color.BartapCardBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, BartapSpacing.md)
    }

    private func presenceRow(_ group: FriendPresence) -> some View {
        Button {
            HapticEngine.lightTap()
            selectedBar = group.bar
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(Array(group.profiles.prefix(3))) { profile in
                        UserAvatarView(
                            urlString: profile.avatar_url,
                            displayName: profile.display_name,
                            size: 34
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.BartapCardFill, lineWidth: 2))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.bar.name)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.BartapText)
                        .lineLimit(1)

                    Text(friendsSummary(group))
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let location = locationService.location {
                    Text(DistanceService.formattedDistance(from: location, to: group.bar))
                        .BartapPillButton()
                }
            }
            .padding(.horizontal, BartapSpacing.md)
            .padding(.vertical, BartapSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func friendsSummary(_ group: FriendPresence) -> String {
        let names = group.profiles.compactMap { $0.display_name }
        switch names.count {
        case 0:
            return group.profiles.count == 1
                ? String(localized: "A friend is here")
                : String(localized: "\(group.profiles.count) friends here")
        case 1:
            return String(localized: "\(names[0]) is here")
        case 2:
            return String(localized: "\(names[0]) and \(names[1]) are here")
        default:
            return String(localized: "\(names[0]), \(names[1]) +\(names.count - 2) more")
        }
    }

    private func load() async {
        guard userSession.currentUser != nil else {
            isLoading = false
            return
        }
        do {
            let ids = try await SupabaseClient.shared.fetchFollowing()
            followingIDs = Set(ids)
            if !ids.isEmpty {
                profiles = try await SupabaseClient.shared.fetchProfilesByIDs(ids)
            }
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }
}
