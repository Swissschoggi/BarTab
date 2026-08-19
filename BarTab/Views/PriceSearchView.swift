import SwiftUI

struct PriceSearchView: View {

    @EnvironmentObject private var barRepository: BarRepository

    @StateObject private var locationService = LocationService()


    @State private var selectedDrinks: Set<Drink> = [.beer]

    @State private var selectedSizes: Set<DrinkSize> = [.fiveDeciliters]

    enum SortOption {
        case cheapest
        case closest
    }

    @State private var sortOption: SortOption = .cheapest


    private var availableSizes: [DrinkSize] {

        var sizes = Set<DrinkSize>()

        for drink in selectedDrinks {

            switch drink {

            case .beer:
                sizes.formUnion([
                    .twentyCentiliters,
                    .twentyFiveCentiliters,
                    .thirtyThreeCentiliters,
                    .fiveDeciliters,
                    .bottle
                ])

            case .wine:
                sizes.formUnion([
                    .oneDeciliter,
                    .twoDeciliters,
                    .threeDeciliters,
                    .bottle,
                    .glass
                ])

            case .cocktail:
                sizes.insert(.glass)

            case .shot:
                sizes.insert(.shot)

            case .softDrink:
                sizes.formUnion([
                    .twentyCentiliters,
                    .twentyFiveCentiliters,
                    .thirtyThreeCentiliters,
                    .fiftyCentiliters,
                    .bottle
                ])

            case .coffee:
                sizes.formUnion([
                    .oneDeciliter,
                    .twoDeciliters,
                    .threeDeciliters,
                    .glass
                ])

            case .other:
                sizes.formUnion(DrinkSize.allCases)
            }
        }

        return DrinkSize.allCases.filter {
            sizes.contains($0)
        }
    }


    private var matchingPrices: [(bar: Bar, price: Price)] {

        var results: [(bar: Bar, price: Price)] = []

        for bar in barRepository.getBars() {

            let prices = barRepository.getPrices(for: bar)

            for price in prices {

                guard selectedDrinks.contains(price.drink) else {
                    continue
                }

                guard selectedSizes.contains(price.size) else {
                    continue
                }

                results.append(
                    (
                        bar: bar,
                        price: price
                    )
                )
            }
        }


        guard let userLocation = locationService.location else {

            return results.sorted {
                $0.price.amount < $1.price.amount
            }
        }

        switch sortOption {

        case .cheapest:

            return results.sorted {
                $0.price.amount < $1.price.amount
            }

        case .closest:

            return results.sorted {

                let firstDistance =
                    DistanceService.distance(
                        from: userLocation,
                        to: $0.bar
                    )

                let secondDistance =
                    DistanceService.distance(
                        from: userLocation,
                        to: $1.bar
                    )

                return firstDistance < secondDistance
            }
        }
    }


    var body: some View {

        NavigationView {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 6) {

                        Text("Find a price")
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold
                                )
                            )

                        Text(
                            "See what bars around you charge."
                        )
                        .foregroundColor(.secondary)
                    }


                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        Text("Drink")
                            .font(.headline)

                        ScrollView(
                            .horizontal,
                            showsIndicators: false
                        ) {

                            HStack(spacing: 10) {

                                ForEach(
                                    Drink.allCases,
                                    id: \.self
                                ) { drink in

                                    Button {

                                        if selectedDrinks.contains(drink) {


                                            if selectedDrinks.count > 1 {
                                                selectedDrinks.remove(drink)
                                            }

                                        } else {

                                            selectedDrinks.insert(drink)
                                        }

                                    } label: {

                                        HStack(spacing: 6) {

                                            Image(
                                                systemName:
                                                    icon(for: drink)
                                            )

                                            Text(
                                                drink.displayName
                                            )
                                        }
                                        .padding(
                                            .horizontal,
                                            14
                                        )
                                        .padding(
                                            .vertical,
                                            10
                                        )
                                        .foregroundColor(
                                            selectedDrinks.contains(drink)
                                            ? .white
                                            : .barTabPrimary
                                        )
                                        .background(
                                            selectedDrinks.contains(drink)
                                            ? Color.barTabPrimary
                                            : Color.barTabPrimary
                                                .opacity(0.12)
                                        )
                                        .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }


                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        Text("Size")
                            .font(.headline)

                        ScrollView(
                            .horizontal,
                            showsIndicators: false
                        ) {

                            HStack(spacing: 10) {

                                ForEach(
                                    availableSizes,
                                    id: \.self
                                ) { size in

                                    Button {

                                        if selectedSizes.contains(size) {

                                            if selectedSizes.count > 1 {
                                                selectedSizes.remove(size)
                                            }

                                        } else {

                                            selectedSizes.insert(size)
                                        }

                                    } label: {

                                        Text(
                                            size.displayName
                                        )
                                        .padding(
                                            .horizontal,
                                            14
                                        )
                                        .padding(
                                            .vertical,
                                            10
                                        )
                                        .foregroundColor(
                                            selectedSizes.contains(size)
                                            ? .white
                                            : .barTabPrimary
                                        )
                                        .background(
                                            selectedSizes.contains(size)
                                            ? Color.barTabPrimary
                                            : Color.barTabPrimary
                                                .opacity(0.12)
                                        )
                                        .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }


                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Text("Sort by")
                            .font(.headline)

                        HStack(spacing: 10) {

                            sortButton(
                                title: "Cheapest",
                                option: .cheapest
                            )

                            sortButton(
                                title: "Closest",
                                option: .closest
                            )
                        }
                    }


                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        HStack {

                            Text("Results")
                                .font(.title3)
                                .fontWeight(.bold)

                            Spacer()

                            Text(
                                "\(matchingPrices.count)"
                            )
                            .foregroundColor(.secondary)
                        }

                        if matchingPrices.isEmpty {

                            VStack(spacing: 10) {

                                Image(
                                    systemName:
                                        "magnifyingglass"
                                )
                                .font(
                                    .system(
                                        size: 35
                                    )
                                )
                                .foregroundColor(
                                    .barTabPrimary
                                )

                                Text("No prices found")
                                    .font(.headline)

                                Text(
                                    "Be the first to add this price."
                                )
                                .font(.subheadline)
                                .foregroundColor(
                                    .secondary
                                )
                            }
                            .frame(
                                maxWidth: .infinity
                            )
                            .padding(
                                .vertical,
                                40
                            )

                        } else {

                            ForEach(
                                matchingPrices,
                                id: \.price.id
                            ) { result in

                                NavigationLink(
                                    destination:
                                        BarView(bar: result.bar)
                                            .environmentObject(
                                                barRepository
                                            )
                                            .environmentObject(
                                                UserSession()
                                            )
                                ) {
                                    resultRow(
                                        bar: result.bar,
                                        price: result.price
                                    )
                                }
                                .buttonStyle(
                                    PlainButtonStyle()
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 70)
                .padding(.bottom, 30)
                
            }
            .background(
                Color.barTabBackground
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(
                .inline
            )


            .onChange(of: selectedDrinks) { _ in

                let validSizes =
                    Set(availableSizes)

                selectedSizes =
                    selectedSizes.filter {
                        validSizes.contains($0)
                    }


                if selectedSizes.isEmpty,
                   let firstSize = availableSizes.first {

                    selectedSizes.insert(
                        firstSize
                    )
                }
            }


            .onAppear {

                locationService.requestPermission()
            }
        }
    }


    private func resultRow(
        bar: Bar,
        price: Price
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text(bar.name)
                        .font(.headline)

                    Text(
                        "\(price.drink.displayName) · " +
                        "\(price.size.displayName)"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if let location =
                        locationService.location {

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

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 2
                ) {
                    Text(
                        price.amount.description
                    )
                    .font(.headline)
                    .foregroundColor(
                        .barTabPrimary
                    )

                    Text(price.currency)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            confidenceView(
                price: price,
                bar: bar
            )
        }
        .padding()
        .background(
            Color.white.opacity(0.7)
        )
        .cornerRadius(14)
    }


    private func sortButton(
        title: String,
        option: SortOption
    ) -> some View {

        Button {

            sortOption = option

        } label: {

            HStack(spacing: 5) {

                Image(
                    systemName:
                        option == .cheapest
                        ? "arrow.down"
                        : "location"
                )

                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(
                sortOption == option
                ? .white
                : .barTabPrimary
            )
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                9
            )
            .background(
                sortOption == option
                ? Color.barTabPrimary
                : Color.barTabPrimary
                    .opacity(0.12)
            )
            .cornerRadius(18)
        }
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
    private func confidenceView(
        price: Price,
        bar: Bar
    ) -> some View {
        let confidence =
            barRepository.confidenceForPrice(
                price,
                at: bar
            )

        let label: String

        switch confidence {
        case 80...:
            label = "Very reliable"
        case 60..<80:
            label = "Reliable"
        case 40..<60:
            label = "Somewhat reliable"
        default:
            label = "Low confidence"
        }

        return VStack(
            alignment: .leading,
            spacing: 5
        ) {
            HStack {
                Text("Price confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            Color.barTabPrimary
                                .opacity(0.12)
                        )

                    Capsule()
                        .fill(Color.barTabPrimary)
                        .frame(
                            width:
                                geometry.size.width *
                                CGFloat(confidence) / 100
                        )
                }
            }
            .frame(height: 6)
        }
    }
}


struct PriceSearchView_Previews: PreviewProvider {

    static var previews: some View {

        PriceSearchView()
            .environmentObject(
                BarRepository()
            )
            .environmentObject(
                UserSession()
            )
    }
}
