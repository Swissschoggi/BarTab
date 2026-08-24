import SwiftUI

struct ProfileView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository

    @State private var showingLogin = false
    @State private var showingSettings = false

    private var currentUser: User? {
        userSession.currentUser
    }

    private var unreviewedReportCount: Int {
        barRepository.unreviewedReportCount
    }

    private var totalContributions: Int {
        guard let user = currentUser else { return 0 }
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


                    VStack(alignment: .leading, spacing: 6) {

                        BarTabScreenHeader(
                            title: "Me",
                            subtitle: currentUser == nil
                                ? "Sign in to manage your contributions."
                                : "Your BarTab profile."
                        )
                    }

                    if let user = currentUser {


                        VStack(alignment: .leading, spacing: 12) {

                            HStack(spacing: 14) {

                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.barTabPrimary,
                                                    Color.barTabPrimary.opacity(0.7)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )

                                    Image(
                                        systemName: "person.fill"
                                    )
                                    .font(.title3)
                                    .foregroundColor(
                                        .white
                                    )
                                }
                                .frame(
                                    width: 48,
                                    height: 48
                                )

                                VStack(
                                    alignment: .leading,
                                    spacing: 2
                                ) {

                                    Text(user.username)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.barTabText)

                                    Text(
                                        "Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        .barTabSecondary
                                    )
                                }

                                Spacer()
                            }
                        }
                        .barTabCard()

                        // Level card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: currentLevel.icon)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.barTabAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(currentLevel.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.barTabText)

                                    if let remaining = UserLevel.remaining(for: totalContributions) {
                                        Text("\(remaining) more to next level")
                                            .font(.caption2)
                                            .foregroundColor(.barTabSecondary)
                                    } else {
                                        Text("Max level reached!")
                                            .font(.caption2)
                                            .foregroundColor(.barTabAccent)
                                    }
                                }

                                Spacer()

                                Text("\(totalContributions)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.barTabAccent)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.barTabPillFill)

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.barTabAccent, .barTabAccent.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(UserLevel.progress(for: totalContributions)))
                                }
                            }
                            .frame(height: 5)
                        }
                        .barTabCard()

                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {

                            Text("Your activity")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.barTabText)

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
                        }


                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {

                            Text("Contributions")
                                .font(.headline)

                            navigationRow(
                                title: String(localized: "My drinks"),
                                subtitle: "\(myPrices.count) contributions",
                                icon: "tag.fill"
                            ) {
                                MyContributionsView()
                            }

                            navigationRow(
                                title: String(localized: "My bars"),
                                subtitle: "\(myBars.count) bars added",
                                icon: "building.2.fill"
                            ) {
                                MyBarsView()
                            }
                        }


                        if let user = currentUser,
                            user.isAdmin {

                            VStack(
                                alignment: .leading,
                                spacing: 10
                            ) {

                                Text("Admin")
                                    .font(.headline)

                                navigationRow(
                                    title: String(localized: "Reported content"),
                                    subtitle: unreviewedReportCount == 0
                                        ? String(localized: "Nothing to review")
                                        : "\(unreviewedReportCount) "
                                        + "\(unreviewedReportCount == 1 ? "report" : "reports") to review",
                                    icon: "flag.fill"
                                ) {
                                    AdminReportsView()
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


                        if !barRepository.favoriteBars.isEmpty {

                            VStack(
                                alignment: .leading,
                                spacing: 10
                            ) {

                                Text("Favorites")
                                    .font(.headline)

                                ForEach(
                                    barRepository.favoriteBars
                                ) { bar in

                                    navigationRow(
                                        title: bar.name,
                                        subtitle: bar.address,
                                        icon: "heart.fill"
                                    ) {
                                        BarView(bar: bar)
                                            .environmentObject(
                                                barRepository
                                            )
                                            .environmentObject(
                                                userSession
                                            )
                                    }
                                }
                            }
                        }


                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {

                            Text("Account")
                                .font(.headline)

                            Button {
                                showingSettings = true
                            } label: {

                                HStack(spacing: 12) {

                                    Image(
                                        systemName: "gearshape.fill"
                                    )
                                    .foregroundColor(.barTabPrimary)

                                    Text("Settings")
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Image(
                                        systemName: "chevron.right"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .barTabCard()
                            }

                            Button {
                                userSession.logout()
                            } label: {

                                HStack(spacing: 12) {

                                    Image(
                                        systemName: "rectangle.portrait.and.arrow.right"
                                    )
                                    .foregroundColor(.red)

                                    Text("Log out")
                                        .foregroundColor(.red)

                                    Spacer()
                                }
                                .barTabCard()
                            }
                        }

                    } else {


                        VStack(spacing: 16) {

                            Image(
                                systemName: "person.crop.circle"
                            )
                            .font(
                                .system(size: 55)
                            )
                            .foregroundColor(
                                .barTabPrimary
                            )

                            Text("You're not signed in")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text(
                                "Sign in to add bars, report drinks and keep track of your contributions."
                            )
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                            Button {
                                showingLogin = true
                            } label: {
                                Text("Sign In")
                                    .font(.headline)
                                    .frame(
                                        maxWidth: .infinity
                                    )
                                    .padding()
                                    .barTabPrimaryButton()
                            }
                        }
                        .padding(.vertical, 40)
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
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(userSession)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(userSession)
                .environmentObject(barRepository)
                .environmentObject(LanguageManager.shared)
        }
    }


    private func statisticCard(
        value: Int,
        title: LocalizedStringKey,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.barTabPrimary)
                .frame(width: 28, height: 28)
                .background(Color.barTabPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.barTabText)

            Text(title)
                .font(.caption)
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
                    .font(.subheadline)
                    .foregroundColor(.barTabPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.barTabPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.barTabText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.barTabSecondary)
                }

                Spacer()

                Image(
                    systemName: "chevron.right"
                )
                .font(.caption2)
                .foregroundColor(.barTabSecondary)
                .foregroundColor(.secondary)
            }
            .barTabCard()
        }
    }
}
