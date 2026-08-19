import SwiftUI

struct PriceSearchView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

    @StateObject private var locationService = LocationService()


    @State private var selectedDrinks: Set<Drink> = [.beer]

    @State private var selectedSizes: Set<DrinkSize> = [.fiveDeciliters]

    enum SortOption {
        case cheapest
        case closest
    }

    @State private var sortOption: SortOption = .cheapest

    @State private var searchText = ""

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var displayedResults: [(bar: Bar, summary: PriceSummary)] {

        guard !trimmedSearchText.isEmpty else {
            return matchingSummaries
        }

        return matchingSummaries.filter {
            $0.bar.name.localizedCaseInsensitiveContains(
                trimmedSearchText
            )
        }
    }

    private var bestDealSummaryID: UUID? {

        displayedResults.min {
            $0.summary.amount < $1.summary.amount
        }?.summary.id
    }


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


    private var matchingSummaries: [(bar: Bar, summary: PriceSummary)] {

        var results: [(bar: Bar, summary: PriceSummary)] = []

        for bar in barRepository.getBars() {

            let summaries =
                barRepository.getPriceSummaries(for: bar)

            for summary in summaries {

                guard selectedDrinks.contains(
                    summary.drink
                ) else {
                    continue
                }

                guard selectedSizes.contains(
                    summary.size
                ) else {
                    continue
                }

                results.append(
                    (
                        bar: bar,
                        summary: summary
                    )
                )
            }
        }


        guard let userLocation = locationService.location else {

            return results.sorted {
                $0.summary.amount < $1.summary.amount
            }
        }

        switch sortOption {

        case .cheapest:

            return results.sorted {
                $0.summary.amount < $1.summary.amount
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

                        BarTabScreenHeader(
                            title: "Find a price",
                            subtitle: "See what bars around you charge."
                        )
                    }


                    HStack(spacing: 10) {

                        Image(
                            systemName: "magnifyingglass"
                        )
                        .foregroundColor(.secondary)

                        TextField(
                            "Search by bar name",
                            text: $searchText
                        )
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                        if !searchText.isEmpty {

                            Button {
                                searchText = ""
                            } label: {
                                Image(
                                    systemName: "xmark.circle.fill"
                                )
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        Color.barTabPrimary.opacity(0.08)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )


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
                                                    drink.icon
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
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: 20,
                                                style: .continuous
                                            )
                                        )
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
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: 20,
                                                style: .continuous
                                            )
                                        )
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
                                "\(displayedResults.count)"
                            )
                            .foregroundColor(.secondary)
                        }

                        if displayedResults.isEmpty {

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
                                    !trimmedSearchText.isEmpty
                                    ? "No bars match \"\(trimmedSearchText)\"."
                                    : "Be the first to add this price."
                                )
                                .font(.subheadline)
                                .foregroundColor(
                                    .secondary
                                )
                                .multilineTextAlignment(.center)
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
                                displayedResults,
                                id: \.summary.id
                            ) { result in

                                NavigationLink(
                                    destination:
                                        BarView(bar: result.bar)
                                            .environmentObject(
                                                barRepository
                                            )
                                            .environmentObject(
                                                userSession
                                            )
                                ) {
                                    resultRow(
                                        bar: result.bar,
                                        summary: result.summary,
                                        isBestDeal:
                                            result.summary.id
                                            == bestDealSummaryID
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
                    .ignoresSafeArea()
            )
            .navigationBarHidden(true)


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
        summary: PriceSummary,
        isBestDeal: Bool = false
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
                    HStack(spacing: 8) {

                        Text(bar.name)
                            .font(.headline)

                        if barRepository.isBarFlagged(bar) {

                            Image(systemName: "flag.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }

                        if isBestDeal {

                            Text("Best deal")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.barTabAccent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(
                        "\(summary.drink.displayName) · " +
                        "\(summary.size.displayName)"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    if let brand = summary.brand {

                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

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
                        "\(summary.formattedAmount) \(summary.currency)"
                    )
                    .font(.headline)
                    .foregroundColor(
                        .barTabPrimary
                    )

                    Text(
                        summary.reportCount == 1
                        ? "1 report"
                        : "\(summary.reportCount) reports"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            confidenceView(summary: summary)
        }
        .barTabCard()
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
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
    }


    private func confidenceView(
        summary: PriceSummary
    ) -> some View {

        let confidence = summary.confidence

        return VStack(
            alignment: .leading,
            spacing: 5
        ) {
            HStack {

                Text("Price confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(
                    "· \(summary.reportCount) \(summary.reportCount == 1 ? "report" : "reports")"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                Spacer()

                Text(summary.confidenceLabel)
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
