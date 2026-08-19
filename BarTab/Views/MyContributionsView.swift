import SwiftUI

struct MyContributionsView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

    private var myPrices: [Price] {

        guard let user = userSession.currentUser else {
            return []
        }

        return barRepository.getPrices(
            reportedBy: user
        )
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                if myPrices.isEmpty {

                    emptyState

                } else {

                    HStack {

                        Text(
                            "\(myPrices.count) \(myPrices.count == 1 ? "contribution" : "contributions")"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        Spacer()
                    }

                    VStack(spacing: 12) {

                        ForEach(
                            myPrices,
                            id: \.id
                        ) { price in

                            contributionCard(
                                price: price
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(
            Color.barTabBackground
                .ignoresSafeArea()
        )
        .navigationTitle("My Contributions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {

        VStack(spacing: 14) {

            ZStack {

                Circle()
                    .fill(
                        Color.barTabPrimary.opacity(0.12)
                    )
                    .frame(
                        width: 72,
                        height: 72
                    )

                Image(
                    systemName: "square.and.pencil"
                )
                .font(.system(size: 28))
                .foregroundColor(
                    .barTabPrimary
                )
            }

            Text("No contributions yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text(
                "Prices you add to bars will appear here."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func contributionCard(
        price: Price
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack(
                alignment: .top,
                spacing: 12
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        Color.barTabPrimary.opacity(0.12)
                    )

                    Image(
                        systemName: icon(
                            for: price.drink
                        )
                    )
                    .font(.title3)
                    .foregroundColor(
                        .barTabPrimary
                    )
                }
                .frame(
                    width: 48,
                    height: 48
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        price.brand
                            ?? price.drink.displayName
                    )
                    .font(.headline)

                    Text(
                        "\(price.drink.displayName) · \(price.size.displayName)"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 1
                ) {

                    Text(
                        price.amount.description
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
                    .foregroundColor(
                        .barTabPrimary
                    )

                    Text(price.currency)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if let bar = barRepository.getBar(
                id: price.barID
            ) {

                HStack(spacing: 8) {

                    Image(
                        systemName: "mappin.circle.fill"
                    )
                    .foregroundColor(
                        .barTabPrimary
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {

                        Text(bar.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(bar.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }

            } else {

                HStack(spacing: 8) {

                    Image(
                        systemName: "mappin.slash"
                    )

                    Text("Bar no longer available")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            Color.white.opacity(0.72)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 5,
            x: 0,
            y: 2
        )
    }

    private func icon(
        for drink: Drink
    ) -> String {

        switch drink {

        case .beer:
            return "mug.fill"

        case .wine:
            return "wineglass.fill"

        case .cocktail:
            return "wineglass"

        case .shot:
            return "flask.fill"

        case .softDrink:
            return "cup.and.saucer.fill"

        case .coffee:
            return "cup.and.saucer.fill"

        case .other:
            return "fork.knife"
        }
    }
}

struct MyContributionsView_Previews: PreviewProvider {

    static var previews: some View {

        NavigationView {

            MyContributionsView()
                .environmentObject(
                    BarRepository()
                )
                .environmentObject(
                    UserSession()
                )
        }
    }
}
