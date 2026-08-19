import SwiftUI

struct ProfileView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository

    @State private var showingLogin = false

    private var currentUser: User? {
        userSession.currentUser
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

                VStack(alignment: .leading, spacing: 24) {


                    VStack(alignment: .leading, spacing: 6) {

                        Text("Me")
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold
                                )
                            )

                        Text(
                            currentUser == nil
                                ? "Sign in to manage your contributions."
                                : "Your BarTab profile."
                        )
                        .foregroundColor(.secondary)
                    }

                    if let user = currentUser {


                        VStack(alignment: .leading, spacing: 14) {

                            HStack(spacing: 14) {

                                ZStack {
                                    Circle()
                                        .fill(
                                            Color.barTabPrimary.opacity(0.15)
                                        )

                                    Image(
                                        systemName: "person.fill"
                                    )
                                    .font(.title2)
                                    .foregroundColor(
                                        .barTabPrimary
                                    )
                                }
                                .frame(
                                    width: 56,
                                    height: 56
                                )

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {

                                    Text(user.username)
                                        .font(.title3)
                                        .fontWeight(.bold)

                                    Text(
                                        "Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        .secondary
                                    )
                                }

                                Spacer()
                            }
                        }
                        .padding()
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .background(
                            Color.white.opacity(0.7)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )


                        VStack(
                            alignment: .leading,
                            spacing: 12
                        ) {

                            Text("Your activity")
                                .font(.headline)

                            HStack(spacing: 12) {

                                statisticCard(
                                    value: myPrices.count,
                                    title: "Prices",
                                    icon: "tag.fill"
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
                                title: "My prices",
                                subtitle: "\(myPrices.count) contributions",
                                icon: "tag.fill"
                            ) {
                                MyContributionsView()
                            }

                            navigationRow(
                                title: "My bars",
                                subtitle: "\(myBars.count) bars added",
                                icon: "building.2.fill"
                            ) {
                                MyContributionsView()
                            }
                        }


                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {

                            Text("Account")
                                .font(.headline)

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
                                .padding()
                                .background(
                                    Color.white.opacity(0.7)
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 14,
                                        style: .continuous
                                    )
                                )
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
                                "Sign in to add bars, report prices and keep track of your contributions."
                            )
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                            Button {
                                showingLogin = true
                            } label: {
                                Text("Sign In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(
                                        maxWidth: .infinity
                                    )
                                    .padding()
                                    .background(
                                        Color.barTabPrimary
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: 14,
                                            style: .continuous
                                        )
                                    )
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
    }


    private func statisticCard(
        value: Int,
        title: String,
        icon: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Image(systemName: icon)
                .foregroundColor(
                    .barTabPrimary
                )

            Text("\(value)")
                .font(
                    .system(
                        size: 26,
                        weight: .bold
                    )
                )

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color.white.opacity(0.7)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
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

            HStack(spacing: 14) {

                Image(systemName: icon)
                    .foregroundColor(
                        .barTabPrimary
                    )
                    .frame(width: 24)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(
                    systemName: "chevron.right"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                Color.white.opacity(0.7)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
        }
    }
}
