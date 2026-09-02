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
        NavigationView {

            ScrollView {

                VStack(alignment: .leading, spacing: 20) {

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
                .padding(.top, 70)
                .padding(.bottom, 30)
            }
            .background(
                Color.barTabBackground
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
            "Log out?",
            isPresented: $showingLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log out", role: .destructive) {
                HapticEngine.impact()
                withAnimation(.easeInOut(duration: 0.3)) {
                    userSession.logout()
                }
                toastCenter.show(
                    "You've been logged out.",
                    kind: .info
                )
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to add bars, prices and ratings.")
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

            BarTabScreenHeader(
                title: "Me",
                subtitle: currentUser == nil
                    ? "Sign in to manage your contributions."
                    : "Your BarTab profile."
            )

            if let fetchedAt = barRepository.lastFetchedAt {
                Text("Data updated \(fetchedAt.relativeFormatted)")
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func profileCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 14) {

                avatarView(user: user)

                VStack(alignment: .leading, spacing: 2) {

                    Text(user.username)
                        .font(.barTabHeading)
                        .fontWeight(.bold)
                        .foregroundColor(.barTabText)

                    Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.barTabSmall)
                        .foregroundColor(.barTabSecondary)

                    PhotosPicker(
                        selection: $selectedAvatarItem,
                        matching: .images
                    ) {
                        Text(isUploadingAvatar ? "Uploading…" : "Change photo")
                            .font(.barTabSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabPrimary)
                    }
                    .disabled(isUploadingAvatar)
                }

                Spacer()
            }

            Divider()
                .foregroundColor(.barTabCardBorder)

            // Level + progress
            HStack(spacing: 12) {
                Image(systemName: currentLevel.icon)
                    .font(.barTabBody)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.barTabAccent)
                    .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentLevel.name)
                        .font(.barTabBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabText)

                    if let remaining = UserLevel.remaining(for: totalContributions) {
                        Text("\(remaining) more to next level")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSecondary)
                    } else {
                        Text("Max level reached!")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabAccent)
                    }
                }

                Spacer()

                Text("\(totalContributions)")
                    .font(.barTabHeading)
                    .fontWeight(.bold)
                    .foregroundColor(.barTabAccent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.barTabPillFill)

                    Capsule()
                        .fill(Color.barTabAccent)
                        .frame(width: geometry.size.width * CGFloat(UserLevel.progress(for: totalContributions)))
                }
            }
            .frame(height: 5)
        }
        .barTabCard()
    }

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Your activity")
                .font(.barTabHeading)

            HStack(spacing: 10) {
                statisticCard(
                    value: myPrices.count,
                    title: "Drinks",
                    icon: "mug.fill"
                )

                statisticCard(
                    value: myBars.count,
                    title: "Bars",
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
                    .foregroundColor(.barTabCardBorder)
                    .padding(.leading, 44)

                navigationRow(
                    title: String(localized: "My bars"),
                    subtitle: "\(myBars.count) bars added",
                    icon: "building.2.fill"
                ) {
                    MyBarsView()
                }

                Divider()
                    .foregroundColor(.barTabCardBorder)
                    .padding(.leading, 44)

                navigationRow(
                    title: "Badges",
                    subtitle: "Your achievements",
                    icon: "rosette"
                ) {
                    BadgeGridView(
                        earnedBadges: BadgeService.shared.earnedBadges(),
                        allBadges: BadgeService.shared.allBadges(),
                        streak: BadgeService.shared.currentStreak
                    )
                }
            }
            .barTabCard()
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved")
                .font(.barTabHeading)

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
                            .foregroundColor(.barTabCardBorder)
                            .padding(.leading, 44)
                    }
                }

                navigationRow(
                    title: "Price Alerts",
                    subtitle: "Get notified on price changes",
                    icon: "bell.fill"
                ) {
                    PriceAlertListView()
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                }
            }
            .barTabCard()
        }
    }

    @ViewBuilder
    private var adminSection: some View {
        if let user = currentUser, user.isAdmin {

            VStack(alignment: .leading, spacing: 10) {

                Text("Admin")
                    .font(.barTabHeading)

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
        VStack(alignment: .leading, spacing: 10) {
            Text("Social")
                .font(.barTabHeading)

            socialRows
        }
    }

    @ViewBuilder
    private var socialRows: some View {
        VStack(spacing: 0) {
            navigationRow(
                title: "Friends",
                subtitle: "Find people, requests and following",
                icon: "person.2.fill"
            ) {
                FriendsView()
            }

            Divider()
                .foregroundColor(.barTabCardBorder)
                .padding(.leading, 44)

            navigationRow(
                title: "Activity",
                subtitle: "See what friends are drinking",
                icon: "list.bullet.rectangle"
            ) {
                ActivityFeedView()
            }

            Divider()
                .foregroundColor(.barTabCardBorder)
                .padding(.leading, 44)

            navigationRow(
                title: "Groups",
                subtitle: "Plan nights out",
                icon: "person.3.fill"
            ) {
                GroupPlanningView()
            }
        }
        .barTabCard()
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Account")
                .font(.barTabHeading)

            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.barTabPrimary)

                    Text("Settings")
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.barTabSmall)
                        .foregroundColor(.secondary)
                }
                .barTabCard()
            }

            Button {
                showingLeaderboard = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.barTabAccent)

                    Text("Leaderboard")
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.barTabSmall)
                        .foregroundColor(.secondary)
                }
                .barTabCard()
            }

            Button {
                showingLogoutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.barTabDanger)

                    Text("Log out")
                        .foregroundColor(.barTabDanger)

                    Spacer()
                }
                .barTabCard()
            }
        }
    }

    @ViewBuilder
    private var signedOutSection: some View {
        VStack(spacing: 16) {

            Image(systemName: "person.crop.circle")
                .font(.barTabEmptyIconLarge)
                .foregroundColor(.barTabPrimary)

            Text("You're not signed in")
                .font(.barTabHeading)
                .fontWeight(.semibold)

            Text("Sign in to add bars, report drinks and keep track of your contributions.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button {
                showingLogin = true
            } label: {
                Text("Sign In")
                    .font(.barTabHeading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .barTabPrimaryButton()
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
                .fill(Color.barTabPrimary)

            Image(systemName: "person.fill")
                .font(.barTabHeading)
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
                    toastCenter.show("That photo couldn't be loaded.", kind: .error)
                    return
                }

                try await userSession.updateAvatar(image: image)
                isUploadingAvatar = false
                toastCenter.show("Profile photo updated", kind: .success)
            } catch {
                isUploadingAvatar = false
                toastCenter.showError(error)
            }
        }
    }

    private func statisticCard(
        value: Int,
        title: LocalizedStringKey,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Image(systemName: icon)
                .font(.barTabBody)
                .foregroundColor(.barTabPrimary)
                .frame(width: 28, height: 28)
                .background(Color.barTabPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))

            Text("\(value)")
                .font(.barTabHeading)
                .fontWeight(.bold)
                .foregroundColor(.barTabText)

            Text(title)
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .barTabCard()
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
                    .font(.barTabBody)
                    .foregroundColor(.barTabPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.barTabPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {

                    Text(title)
                        .font(.barTabBody)
                        .fontWeight(.medium)
                        .foregroundColor(.barTabText)

                    Text(subtitle)
                        .font(.barTabSmall)
                        .foregroundColor(.barTabSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)
            }
            .barTabCard()
        }
    }
}

/// Combines find-friends, follow requests and following into one screen.
struct FriendsView: View {

    private enum Tab: String, CaseIterable {
        case find = "Find"
        case requests = "Requests"
        case following = "Following"
    }

    @State private var tab: Tab = .find

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $tab) {
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
            case .following:
                FollowingListView()
            }
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
    }
}
