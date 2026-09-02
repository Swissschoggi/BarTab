import SwiftUI

struct MyContributionsView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var editingPrice: Price?

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
                        .font(.barTabBody)
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
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: false
                            ) {

                                if let user = userSession.currentUser {

                                    Button(role: .destructive) {
                                        Task {
                                            await barRepository.deletePrice(
                                                price,
                                                reportedBy: user
                                            )
                                        }
                                    } label: {
                                        Label(
                                            "Delete",
                                            systemImage: "trash"
                                        )
                                    }

                                    Button {
                                        editingPrice = price
                                    } label: {
                                        Label(
                                            "Edit",
                                            systemImage: "pencil"
                                        )
                                    }
                                    .tint(.barTabPrimary)
                                }
                            }
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
        .sheet(item: $editingPrice) { price in
            if let bar = barRepository.getBar(id: price.barID) {
                AddPriceView(
                    bar: bar,
                    editingPrice: price
                )
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
            }
        }
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
                .font(.barTabHeading)
                .fontWeight(.semibold)

            Text(
                "Drinks you add to bars will appear here."
            )
            .font(.barTabBody)
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
                        cornerRadius: BarTabRadius.control,
                        style: .continuous
                    )
                    .fill(
                        Color.barTabPrimary.opacity(0.12)
                    )

                    Image(
                        systemName: price.drink.icon
                    )
                    .font(.barTabHeading)
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
                    .font(.barTabHeading)

                    Text(
                        "\(price.drink.displayName) · \(price.size.displayName)"
                    )
                    .font(.barTabBody)
                    .foregroundColor(.secondary)
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 1
                ) {

                    Text(
                        price.formattedAmount
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
                        .font(.barTabSmall)
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
                            .font(.barTabBody)
                            .fontWeight(.medium)

                        Text(bar.address)
                            .font(.barTabSmall)
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
                        .font(.barTabSmall)
                }
                .foregroundColor(.secondary)
            }
        }
        .barTabCard()
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
                .environmentObject(
                    ToastCenter()
                )
        }
    }
}
