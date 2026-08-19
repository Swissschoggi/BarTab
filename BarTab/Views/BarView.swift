import SwiftUI
import CoreLocation

struct BarView: View {

    let bar: Bar

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

    @State private var showingAddPrice = false

    private var prices: [Price] {
        barRepository.getPrices(for: bar)
    }

    private struct PriceGroup: Identifiable {
        let drink: Drink
        let size: DrinkSize
        let brand: String?
        var prices: [Price]

        var id: String {
            "\(drink)-\(size)-\(brand ?? "")"
        }
    }

    private var groupedPrices: [PriceGroup] {
        var groups: [PriceGroup] = []

        for price in prices {
            if let index = groups.firstIndex(where: {
                $0.drink == price.drink &&
                $0.size == price.size &&
                $0.brand == price.brand
            }) {
                groups[index].prices.append(price)
            } else {
                groups.append(
                    PriceGroup(
                        drink: price.drink,
                        size: price.size,
                        brand: price.brand,
                        prices: [price]
                    )
                )
            }
        }

        return groups.sorted {
            averageAmount(for: $0) < averageAmount(for: $1)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        Text(bar.name)
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold
                                )
                            )

                        Text(bar.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let location = CLLocationManager().location {
                            Text(
                                DistanceService.formattedDistance(
                                    from: location,
                                    to: bar
                                )
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        HStack {
                            Text("Prices")
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()

                            Text("\(groupedPrices.count)")
                                .foregroundColor(.secondary)
                        }

                        if groupedPrices.isEmpty {
                            emptyPricesView
                        } else {
                            ForEach(groupedPrices) { group in
                                priceGroupRow(group)
                            }
                        }
                    }

                    Button {
                        showingAddPrice = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")

                            Text("Add a price")
                                .fontWeight(.semibold)

                            Spacer()

                            Image(
                                systemName: "chevron.right"
                            )
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Color.barTabPrimary
                        )
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .background(
                Color.barTabBackground
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(
            isPresented: $showingAddPrice
        ) {
            AddPriceView(bar: bar)
                .environmentObject(barRepository)
                .environmentObject(userSession)
        }
    }

    private func priceGroupRow(
        _ group: PriceGroup
    ) -> some View {

        let confidence = confidenceForGroup(group)
        let average = averageAmount(for: group)

        return VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    HStack(spacing: 6) {
                        Text(group.drink.displayName)
                            .font(.headline)

                        if let brand = group.brand {
                            Text("·")
                                .foregroundColor(.secondary)

                            Text(brand)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(group.size.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 2
                ) {
                    Text(
                        "\(formatAmount(average)) CHF"
                    )
                    .font(
                        .system(
                            size: 19,
                            weight: .bold
                        )
                    )
                    .foregroundColor(
                        .barTabPrimary
                    )

                    Text(
                        group.prices.count == 1
                        ? "1 report"
                        : "\(group.prices.count) reports"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                HStack {
                    Text("Price confidence")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(confidence)%")
                        .font(.caption)
                        .fontWeight(.bold)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(
                                Color.barTabPrimary
                                    .opacity(0.12)
                            )

                        Capsule()
                            .fill(
                                Color.barTabPrimary
                            )
                            .frame(
                                width:
                                    geometry.size.width
                                    * CGFloat(confidence)
                                    / 100
                            )
                    }
                }
                .frame(height: 7)

                Text(
                    confidenceDescription(
                        confidence
                    )
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            Color.white.opacity(0.75)
        )
        .cornerRadius(14)
    }


    private func confidenceForGroup(
        _ group: PriceGroup
    ) -> Int {

        let now = Date()

        let recentPrices = group.prices.filter {
            now.timeIntervalSince(
                $0.reportedAt
            ) <= 365 * 24 * 60 * 60
        }

        guard !recentPrices.isEmpty else {
            return 20
        }

        let reportScore = min(
            Double(recentPrices.count) / 8.0,
            1.0
        )

        let recencyScore = recentPrices.reduce(0.0) {
            partial,
            price in

            let age =
                now.timeIntervalSince(
                    price.reportedAt
                )

            let days =
                age / (24 * 60 * 60)

            let freshness =
                max(
                    0.0,
                    1.0 - days / 365.0
                )

            return partial + freshness
        } / Double(recentPrices.count)

        let amounts = recentPrices.map {
            NSDecimalNumber(
                decimal: $0.amount
            ).doubleValue
        }

        let average =
            amounts.reduce(0, +)
            / Double(amounts.count)

        let deviations = amounts.map {
            abs($0 - average)
        }

        let averageDeviation =
            deviations.reduce(0, +)
            / Double(deviations.count)

        let agreementScore =
            max(
                0.0,
                1.0
                - averageDeviation
                / max(average, 1.0)
            )

        let score =
            reportScore * 0.45
            + recencyScore * 0.30
            + agreementScore * 0.25

        return Int(
            (score * 100).rounded()
        )
    }

    private func confidenceDescription(
        _ confidence: Int
    ) -> String {

        switch confidence {
        case 85...:
            return "Highly reliable — many recent reports agree"

        case 65..<85:
            return "Reliable — recent reports mostly agree"

        case 40..<65:
            return "Moderate confidence — prices vary somewhat"

        case 20..<40:
            return "Low confidence — few or older reports"

        default:
            return "Very low confidence — more reports needed"
        }
    }


    private func averageAmount(
        for group: PriceGroup
    ) -> Decimal {

        let total = group.prices.reduce(
            Decimal.zero
        ) { result, price in
            result + price.amount
        }

        return total / Decimal(
            group.prices.count
        )
    }

    private func formatAmount(
        _ amount: Decimal
    ) -> String {

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(
            from: amount as NSDecimalNumber
        ) ?? amount.description
    }


    private var emptyPricesView: some View {
        VStack(spacing: 10) {
            Image(
                systemName: "wineglass"
            )
            .font(
                .system(size: 40)
            )
            .foregroundColor(
                .barTabPrimary
            )

            Text("No prices yet")
                .font(.headline)

            Text(
                "Be the first person to add a price here."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 35)
    }
}

struct BarView_Previews: PreviewProvider {

    static var previews: some View {
        if let bar = Bar.mockBars.first {
            BarView(bar: bar)
                .environmentObject(
                    BarRepository()
                )
                .environmentObject(
                    UserSession()
                )
        }
    }
}
