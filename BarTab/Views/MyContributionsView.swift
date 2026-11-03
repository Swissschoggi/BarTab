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
                            String(localized: "\(myPrices.count) \(myPrices.count == 1 ? "contribution" : "contributions")")
                        )
                        .font(.BartapBody)
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
                                            String(localized: "Delete"),
                                            systemImage: "trash"
                                        )
                                    }

                                    Button {
                                        editingPrice = price
                                    } label: {
                                        Label(
                                            String(localized: "Edit"),
                                            systemImage: "pencil"
                                        )
                                    }
                                    .tint(.BartapPrimary)
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
            Color.BartapBackground
                .ignoresSafeArea()
        )
        .navigationTitle(String(localized: "My Contributions"))
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

        VStack(spacing: BartapSpacing.sm) {

            ZStack {

                Circle()
                    .fill(
                        Color.BartapPrimary.opacity(0.12)
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
                    .BartapPrimary
                )
            }

            Text(String(localized: "No contributions yet"))
                .font(.BartapHeading)
                .fontWeight(.semibold)

            Text(
                String(localized: "Drinks you add to bars will appear here.")
            )
            .font(.BartapBody)
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
            spacing: BartapSpacing.sm
        ) {

            HStack(
                alignment: .top,
                spacing: 12
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: BartapRadius.control,
                        style: .continuous
                    )
                    .fill(
                        Color.BartapPrimary.opacity(0.12)
                    )

                    Image(
                        systemName: price.drink.icon
                    )
                    .font(.BartapHeading)
                    .foregroundColor(
                        .BartapPrimary
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
                    .font(.BartapHeading)

                    Text(
                        "\(price.drink.displayName) · \(price.size.displayName)"
                    )
                    .font(.BartapBody)
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
                        .BartapPrimary
                    )

                    Text(price.currency)
                        .font(.BartapSmall)
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
                        .BartapPrimary
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 2
                    ) {

                        Text(bar.name)
                            .font(.BartapBody)
                            .fontWeight(.medium)

                        Text(bar.address)
                            .font(.BartapSmall)
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

                    Text(String(localized: "Bar no longer available"))
                        .font(.BartapSmall)
                }
                .foregroundColor(.secondary)
            }
        }
        .BartapCard()
    }

}

struct MyContributionsView_Previews: PreviewProvider {

    static var previews: some View {

        NavigationStack {

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
