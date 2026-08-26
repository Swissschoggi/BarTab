import SwiftUI
import MapKit

struct BarView: View {

    let bar: Bar
    let allowsDismissal: Bool

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var locationService = LocationService()

    @State private var showingAddPrice = false
    @State private var expandedGroupID: String?
    @State private var expandedDrinkCategories: Set<Drink> = Set(Drink.allCases)

    @State private var showingBarReport = false
    @State private var showingPriceReport = false
    @State private var pendingReportGroup: PriceGroup?

    @State private var showingDeleteBarConfirmation = false
    @State private var pendingDeletePrice: Price?
    @State private var showingDeletePriceConfirmation = false
    @State private var pendingDeleteGroup: PriceGroup?
    @State private var showingDeleteGroupConfirmation = false

    @State private var showingRateBar = false
    @State private var showingSmokingConfirmation = false
    @State private var showingOutdoorConfirmation = false
    @State private var ratingDrinkGroup: PriceGroup?
    @State private var showingDrinkRating = false

    init(bar: Bar, allowsDismissal: Bool = false) {
        self.bar = bar
        self.allowsDismissal = allowsDismissal
    }

    private var currentBar: Bar {
        barRepository.getBar(id: bar.id) ?? bar
    }

    private var prices: [Price] {
        barRepository.getPrices(for: currentBar)
    }

    private struct PriceGroup: Identifiable {
        let drink: Drink
        let size: DrinkSize
        let brand: String?
        let style: String?
        let serving: ServingMethod?
        var prices: [Price]

        var id: String {
            "\(drink)-\(size)-\(brand ?? "")-\(style ?? "")-\(serving?.rawValue ?? "")"
        }
    }

    private var groupedPrices: [PriceGroup] {
        var groups: [PriceGroup] = []

        for price in prices {
            if let index = groups.firstIndex(where: {
                $0.drink == price.drink &&
                $0.size == price.size &&
                $0.brand == price.brand &&
                $0.style == price.style &&
                $0.serving == price.serving
            }) {
                groups[index].prices.append(price)
            } else {
                groups.append(
                    PriceGroup(
                        drink: price.drink,
                        size: price.size,
                        brand: price.brand,
                        style: price.style,
                        serving: price.serving,
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
        attachModals(
            to: ScrollView {
                content
                    .padding()
            }
            .background(
                Color.barTabBackground
                    .ignoresSafeArea()
            )
            .navigationTitle(currentBar.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                locationService.requestPermission()
            }
        )
    }

    private var content: some View {
        VStack(
            alignment: .leading,
            spacing: 20
        ) {

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(currentBar.address)
                    .font(.subheadline)
                    .foregroundColor(.barTabSecondary)

                if let location = locationService.location {
                    Label(
                        DistanceService.formattedDistance(
                            from: location,
                            to: currentBar
                        ),
                        systemImage: "location.fill"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.barTabPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.barTabPrimary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            detailsSection

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Text("Menu")
                        .font(.headline)

                    Spacer()

                    Text("\(groupedPrices.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if groupedPrices.isEmpty {
                    emptyPricesView
                } else {
                    ForEach(Drink.allCases.filter { drink in
                        groupedPrices.contains { $0.drink == drink }
                    }) { drink in

                        let drinkGroups = groupedPrices.filter { $0.drink == drink }

                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(drinkGroups) { group in
                                    priceGroupRow(group)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: drink.icon)
                                    .font(.caption)
                                    .foregroundColor(.barTabPrimary)
                                    .frame(width: 20)

                                Text(drink.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)

                                Spacer()

                                Text("\(drinkGroups.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.barTabPrimary.opacity(0.1))
                                    .clipShape(Capsule())
                                    .foregroundColor(.barTabPrimary)
                            }
                        }
                        .tint(.barTabSecondary)
                        .padding(.vertical, 2)
                        .onAppear {
                            expandedDrinkCategories.insert(drink)
                        }
                    }
                }
            }

            Button {
                openDirections()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline)

                    Text("Get Directions")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.barTabPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.barTabPrimary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                showingAddPrice = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline)

                    Text("Add a drink")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding()
                .barTabPrimaryButton()
            }
        }
    }

    private var detailsSection: some View {
        let ambienceStyles = barRepository.ambienceStyles(for: currentBar)
        let ambienceCount = barRepository.ambienceCount(for: currentBar)

        return VStack(alignment: .leading, spacing: 0) {

            if let priceLevel = barRepository.priceLevel(for: currentBar) {
                HStack(spacing: 8) {
                    Text(priceLevel)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.barTabPrimary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(priceLevelTitle(priceLevel))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.barTabText)

                        Text("Average drink price at this bar")
                            .font(.caption2)
                            .foregroundColor(.barTabSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .foregroundColor(.barTabCardBorder)
                    .padding(.horizontal, 16)
            }

            Button {
                showingOutdoorConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: currentBar.outdoorSeating ? "sun.max.fill" : "sun.max")
                        .font(.subheadline)
                        .foregroundColor(currentBar.outdoorSeating ? .white : .barTabPrimary)
                        .frame(width: 32, height: 32)
                        .background(currentBar.outdoorSeating ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentBar.outdoorSeating ? "Outdoor seating" : "Indoor only")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.barTabText)

                        Text("Tap to change")
                            .font(.caption2)
                            .foregroundColor(.barTabSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider()
                .foregroundColor(.barTabCardBorder)
                .padding(.horizontal, 16)

            Button {
                showingSmokingConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: currentBar.smokingFriendly ? "smoke.fill" : "smoke")
                        .font(.subheadline)
                        .foregroundColor(currentBar.smokingFriendly ? .white : .barTabPrimary)
                        .frame(width: 32, height: 32)
                        .background(currentBar.smokingFriendly ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentBar.smokingFriendly ? "Smoking friendly" : "No smoking")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.barTabText)

                        Text("Tap to change")
                            .font(.caption2)
                            .foregroundColor(.barTabSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Divider()
                .foregroundColor(.barTabCardBorder)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ambience")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.barTabText)

                    Spacer()

                    if ambienceCount > 0 {
                        Text("\(ambienceCount) ratings")
                            .font(.caption2)
                            .foregroundColor(.barTabSecondary)
                    } else {
                        Text("No ratings yet")
                            .font(.caption)
                            .foregroundColor(.barTabSecondary)
                    }
                }

                if !ambienceStyles.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(ambienceStyles) { style in
                            HStack(spacing: 3) {
                                Image(systemName: style.icon)
                                    .font(.caption2)
                                Text(style.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.barTabPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.barTabPrimary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Button {
                showingRateBar = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("Rate this bar")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .barTabCard()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if allowsDismissal {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                HapticEngine.impact()
                withAnimation(.easeInOut(duration: 0.2)) {
                    barRepository.toggleFavorite(currentBar)
                }
            } label: {
                Image(systemName: barRepository.isFavorite(currentBar) ? "heart.fill" : "heart")
                    .foregroundColor(.barTabPrimary)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.barTabPrimary)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                handleBarReportTap()
            } label: {
                Image(systemName: currentUserReportedBar ? "flag.fill" : "flag")
                    .foregroundColor(.barTabPrimary)
            }
        }

        if canDeleteBar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDeleteBarConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func attachModals<V: View>(to view: V) -> some View {
        view
            .sheet(isPresented: $showingAddPrice) {
                AddPriceView(bar: currentBar)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            }
            .sheet(isPresented: $showingRateBar) {
                let mine = userSession.currentUser.flatMap {
                    barRepository.myRating(for: currentBar, by: $0)
                }
                RateBarSheet(
                    bar: currentBar,
                    initialAmbience: mine?.ambience ?? []
                )
                .environmentObject(barRepository)
                .environmentObject(userSession)
            }
            .sheet(isPresented: $showingDrinkRating) {
                if let group = ratingDrinkGroup, let user = userSession.currentUser {
                    DrinkRatingSheet(
                        bar: currentBar,
                        drink: group.drink,
                        brand: group.brand,
                        size: group.size,
                        initialQuality: barRepository.myDrinkRating(
                            for: currentBar,
                            drink: group.drink,
                            brand: group.brand,
                            size: group.size,
                            by: user
                        )?.quality
                    )
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                }
            }
            .confirmationDialog(
                "Report this bar?",
                isPresented: $showingBarReport,
                titleVisibility: .visible
            ) {
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) {
                        reportBar(reason: reason)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tell us why this bar looks wrong.")
            }
            .confirmationDialog(
                "Report this drink?",
                isPresented: $showingPriceReport,
                titleVisibility: .visible
            ) {
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) {
                        guard let group = pendingReportGroup else { return }
                        reportPriceGroup(group, reason: reason)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tell us why this drink looks wrong.")
            }
            .confirmationDialog(
                "Delete this bar?",
                isPresented: $showingDeleteBarConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteBar()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the bar and all of its drinks. This can't be undone.")
            }
            .confirmationDialog(
                "Delete this drink entry?",
                isPresented: $showingDeletePriceConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let price = pendingDeletePrice else { return }
                    deletePrice(price)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes this drink entry. This can't be undone.")
            }
            .confirmationDialog(
                "Delete this drink?",
                isPresented: Binding(
                    get: { pendingDeleteGroup != nil },
                    set: { if !$0 { pendingDeleteGroup = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let group = pendingDeleteGroup else { return }
                    deleteGroup(group)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all entries for this drink at this bar. This can't be undone.")
            }
            .confirmationDialog(
                currentBar.smokingFriendly ? "Remove smoking policy?" : "Mark as smoking friendly?",
                isPresented: $showingSmokingConfirmation,
                titleVisibility: .visible
            ) {
                Button(currentBar.smokingFriendly ? "Remove" : "Confirm") {
                    Task {
                        await barRepository.toggleSmokingPolicy(for: currentBar)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    currentBar.smokingFriendly
                        ? "This bar will be marked as no smoking."
                        : "This bar will be marked as smoking friendly."
                )
            }
            .alert(
                currentBar.outdoorSeating ? "Remove outdoor seating?" : "Mark as outdoor seating?",
                isPresented: $showingOutdoorConfirmation
            ) {
                Button(currentBar.outdoorSeating ? "Remove" : "Confirm") {
                    HapticEngine.impact()
                    Task {
                        await barRepository.toggleOutdoorSeating(for: currentBar)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    currentBar.outdoorSeating
                        ? "This bar will be marked as indoor only."
                        : "This bar will be marked as having outdoor seating."
                )
            }
    }

    private func priceGroupRow(_ group: PriceGroup) -> some View {
        let isExpanded = expandedGroupID == group.id
        let isFlagged = barRepository.isPriceGroupFlagged(
            drink: group.drink,
            size: group.size,
            brand: group.brand
        )

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedGroupID = isExpanded ? nil : group.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(group.drink.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)

                                if isFlagged {
                                    Image(systemName: "flag.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }

                                if let brand = group.brand {
                                    Text("·").foregroundColor(.barTabSecondary)
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundColor(.barTabSecondary)
                                }

                                if let style = group.style {
                                    Text("·").foregroundColor(.barTabSecondary)
                                    Text(style)
                                        .font(.caption)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }

                            HStack(spacing: 6) {
                                Text(group.size.displayName)
                                    .font(.caption)
                                    .foregroundColor(.barTabSecondary)

                                if let serving = group.serving {
                                    Text("·").foregroundColor(.barTabSecondary)
                                    Text(serving.displayName)
                                        .font(.caption)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }
                        }

                        Spacer()

                        Text("\(Currency.defaultCurrency.symbol)\(averageAmount(for: group).formattedAmount)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.barTabPrimary)

                        Button {
                            ratingDrinkGroup = group
                            showingDrinkRating = true
                        } label: {
                            Image(systemName: myDrinkRatingIcon(for: group))
                                .font(.caption)
                                .foregroundColor(.barTabPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helper Methods / Properties Placeholder
    private var emptyPricesView: some View {
        Text("No drink prices added yet.")
            .font(.caption)
            .foregroundColor(.barTabSecondary)
            .padding()
    }

    private var shareText: String {
        "Check out \(currentBar.name) on BarTab!"
    }

    private var currentUserReportedBar: Bool { false }
    private var canDeleteBar: Bool { false }

    private func averageAmount(for group: PriceGroup) -> Double {
        guard !group.prices.isEmpty else { return 0.0 }
        let total = group.prices.reduce(Decimal(0)) { $0 + $1.amount }
        let count = Decimal(group.prices.count)
        return NSDecimalNumber(decimal: total / count).doubleValue
    }

    private func confidenceForGroup(_ group: PriceGroup) -> Double { 1.0 }
    private func priceLevelTitle(_ level: String) -> String { "Price Level" }
    private func openDirections() {}
    private func reportBar(reason: ReportReason) {}
    private func reportPriceGroup(_ group: PriceGroup, reason: ReportReason) {}
    private func deleteBar() {}
    private func deletePrice(_ price: Price) {}
    private func deleteGroup(_ group: PriceGroup) {}
    private func handleBarReportTap() {}

    private func myDrinkRatingIcon(for group: PriceGroup) -> String {
        guard let user = userSession.currentUser else { return "star" }
        if barRepository.myDrinkRating(
            for: currentBar,
            drink: group.drink,
            brand: group.brand,
            size: group.size,
            by: user
        ) != nil {
            return "star.fill"
        }
        return "star"
    }
}
