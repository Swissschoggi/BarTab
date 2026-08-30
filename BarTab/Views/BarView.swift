import SwiftUI
import MapKit

struct BarView: View {

    let bar: Bar
    let allowsDismissal: Bool

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var locationService: LocationService

    @State private var showingAddPrice = false
    @State private var expandedGroupID: String?
    @State private var expandedDrinkCategories: Set<Drink> = Set(Drink.allCases)

    @State private var showingBarReport = false
    @State private var showingPriceReport = false
    @State private var pendingReportGroup: PriceGroup?

    @State private var showingDeleteBarConfirmation = false
    @State private var showingEditBar = false
    @State private var pendingDeletePrice: Price?
    @State private var showingDeletePriceConfirmation = false
    @State private var pendingDeleteGroup: PriceGroup?
    @State private var showingDeleteGroupConfirmation = false

    @State private var showingRateBar = false
    @State private var showingSmokingConfirmation = false
    @State private var showingOutdoorConfirmation = false
    @State private var ratingDrinkGroup: PriceGroup?
    @State private var showingDrinkRating = false
    @State private var alertDrinkGroup: PriceGroup?
    @State private var showingPriceAlert = false
    @State private var comparisonGroup: PriceGroup?

    // Cached from @Published — never read barRepository directly in body
    @State private var currentBar: Bar
    @State private var prices: [Price] = []
    @State private var isFavorited = false
    @State private var hasReported = false
    @State private var ambienceStyles: [AmbienceStyle] = []
    @State private var ambienceCount = 0
    @State private var priceLevelString: String?
    @State private var cachedReports: [ContentReport] = []
    @State private var cachedDrinkRatings: [DrinkRating] = []
    @State private var cachedBarRatings: [BarRating] = []

    init(bar: Bar, allowsDismissal: Bool = false) {
        self.bar = bar
        self.allowsDismissal = allowsDismissal
        _currentBar = State(initialValue: bar)
    }

    @State private var isSyncScheduled = false

    private func scheduleSync() {
        guard !isSyncScheduled else { return }
        isSyncScheduled = true
        DispatchQueue.main.async {
            isSyncScheduled = false
            syncFromRepository()
        }
    }

    private func syncFromRepository() {
        if let latest = barRepository.getBar(id: bar.id) {
            currentBar = latest
        }
        prices = barRepository.getPrices(for: currentBar)
        isFavorited = barRepository.favoriteBarIDs.contains(bar.id)
        ambienceStyles = barRepository.ambienceStyles(for: currentBar)
        ambienceCount = barRepository.ambienceCount(for: currentBar)
        priceLevelString = barRepository.priceLevel(for: currentBar)
        cachedReports = barRepository.reports
        cachedDrinkRatings = barRepository.drinkRatings
        cachedBarRatings = barRepository.barRatings
        if let user = userSession.currentUser {
            hasReported = barRepository.reports.contains {
                $0.targetID == bar.id.uuidString
                && $0.targetType == .bar
                && $0.reportedBy == user.id
            }
        }
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
                syncFromRepository()
            }
            .onReceive(barRepository.$bars) { _ in scheduleSync() }
            .onReceive(barRepository.$prices) { _ in scheduleSync() }
            .onReceive(barRepository.$barRatings) { _ in scheduleSync() }
            .onReceive(barRepository.$drinkRatings) { _ in scheduleSync() }
            .onReceive(barRepository.$priceLevelByBarID) { _ in scheduleSync() }
            .onReceive(barRepository.$favoriteBarIDs) { _ in scheduleSync() }
            .onReceive(barRepository.$reports) { _ in scheduleSync() }
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

                if let fetchedAt = barRepository.lastFetchedAt {
                    Text("Updated \(fetchedAt.relativeFormatted)")
                        .font(.caption2)
                        .foregroundColor(.barTabSecondary)
                }

                if groupedPrices.isEmpty {
                    emptyPricesView
                } else {
                    ForEach(Drink.allCases.filter { drink in
                        groupedPrices.contains { $0.drink == drink }
                    }) { drink in

                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(groupedPrices.filter { $0.drink == drink }) { group in
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

                                Text("\(groupedPrices.filter { $0.drink == drink }.count)")
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

            if userSession.currentUser != nil {
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
            } else {
                NavigationLink {
                    LoginView()
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.subheadline)

                        Text("Sign in to add a drink")
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
    }

    private var detailsSection: some View {

        return VStack(alignment: .leading, spacing: 0) {

            if let priceLevel = priceLevelString {
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
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                HapticEngine.impact()
                withAnimation(.easeInOut(duration: 0.2)) {
                    barRepository.toggleFavorite(currentBar)
                }
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .foregroundColor(.barTabPrimary)
            }
            .accessibilityLabel(isFavorited ? "Remove from favorites" : "Add to favorites")
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.barTabPrimary)
            }
            .accessibilityLabel("Share bar")
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                handleBarReportTap()
            } label: {
                Image(systemName: hasReported ? "flag.fill" : "flag")
                    .foregroundColor(.barTabPrimary)
            }
            .accessibilityLabel("Report bar")
        }

        if canDeleteBar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditBar = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.barTabPrimary)
                }
                .accessibilityLabel("Edit bar")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDeleteBarConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete bar")
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
            .sheet(isPresented: $showingEditBar) {
                EditBarView(bar: currentBar)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            }
            .sheet(isPresented: $showingRateBar) {
                RateBarSheet(
                    bar: currentBar,
                    initialAmbience: userSession.currentUser.flatMap {
                        barRepository.myRating(for: currentBar, by: $0)
                    }?.ambience ?? []
                )
                .environmentObject(barRepository)
                .environmentObject(userSession)
            }
            .sheet(isPresented: $showingDrinkRating) {
                if let group = ratingDrinkGroup,
                   let user = userSession.currentUser {
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
            .sheet(isPresented: $showingPriceAlert) {
                if let group = alertDrinkGroup {
                    SetAlertSheet(
                        bar: currentBar,
                        drink: group.drink,
                        size: group.size,
                        brand: group.brand
                    )
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
                }
            }
            .sheet(item: $comparisonGroup) { group in
                DrinkComparisonView(
                    drink: group.drink,
                    brand: group.brand,
                    size: group.size,
                    style: group.style,
                    serving: group.serving
                )
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
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
                isPresented: $showingDeleteGroupConfirmation,
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
                        let barToUpdate = currentBar
                        await barRepository.toggleSmokingPolicy(for: barToUpdate)
                        if let latest = barRepository.getBar(id: bar.id) {
                            currentBar = latest
                        }
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
            .confirmationDialog(
                currentBar.outdoorSeating ? "Remove outdoor seating?" : "Mark as outdoor seating?",
                isPresented: $showingOutdoorConfirmation,
                titleVisibility: .visible
            ) {
                Button(currentBar.outdoorSeating ? "Remove" : "Confirm") {
                    HapticEngine.impact()
                    Task {
                        let barToUpdate = currentBar
                        await barRepository.toggleOutdoorSeating(for: barToUpdate)
                        if let latest = barRepository.getBar(id: bar.id) {
                            currentBar = latest
                        }
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
        let groupKey = "\(group.drink)-\(group.size)-\(group.brand ?? "")-\(group.style ?? "")-\(group.serving?.rawValue ?? "")"
        let isFlagged = cachedReports.contains { $0.targetID == groupKey }

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

                        Text("\(Currency.defaultCurrency.symbol)\(Decimal(averageAmount(for: group)).formattedAmount)")
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
                        .accessibilityLabel("Rate drink")

                        Button {
                            pendingReportGroup = group
                            showingPriceReport = true
                        } label: {
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(isFlagged ? .orange : .barTabSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Report drink price")

                        Button {
                            alertDrinkGroup = group
                            showingPriceAlert = true
                        } label: {
                            Image(systemName: "bell")
                                .font(.caption)
                                .foregroundColor(.barTabSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Set price alert")
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    if group.prices.count > 1 {
                        PriceTrendChart(prices: group.prices)
                            .frame(height: 120)
                            .padding(.horizontal, 4)
                    } else {
                        Text("Only one price reported — trend needs at least two.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }

                    if let user = userSession.currentUser, user.isAdmin {
                        HStack {
                            Spacer()
                            Button {
                                pendingDeleteGroup = group
                                showingDeleteGroupConfirmation = true
                            } label: {
                                Label("Delete all", systemImage: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.bottom, 8)
            }
        }
        .contextMenu {
            Button {
                comparisonGroup = group
            } label: {
                Label("Compare prices", systemImage: "barchart.xaxis.2")
            }
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

    private var canDeleteBar: Bool {
        guard let user = userSession.currentUser else { return false }
        return user.isAdmin || currentBar.createdBy == user.id
    }

    private func averageAmount(for group: PriceGroup) -> Double {
        guard !group.prices.isEmpty else { return 0.0 }
        let total = group.prices.reduce(Decimal(0)) { $0 + $1.amount }
        let count = Decimal(group.prices.count)
        return NSDecimalNumber(decimal: total / count).doubleValue
    }

    private func priceLevelTitle(_ level: String) -> String { "Price Level" }
    private func openDirections() {
        let coordinate = currentBar.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = currentBar.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
    private func reportBar(reason: ReportReason) {
        guard let user = userSession.currentUser else { return }
        barRepository.reportBar(currentBar, reason: reason, reportedBy: user)
        toastCenter.show("Reported — thanks for helping keep BarTab accurate.", kind: .success)
    }

    private func reportPriceGroup(_ group: PriceGroup, reason: ReportReason) {
        guard let user = userSession.currentUser else { return }
        barRepository.reportPriceGroup(
            drink: group.drink,
            size: group.size,
            brand: group.brand,
            style: group.style,
            serving: group.serving,
            reason: reason,
            reportedBy: user
        )
        toastCenter.show("Reported — thanks for helping keep BarTab accurate.", kind: .success)
    }

    private func deleteBar() {
        guard let user = userSession.currentUser else { return }
        Task {
            await barRepository.deleteBar(currentBar, createdBy: user)
            dismiss()
        }
    }

    private func deletePrice(_ price: Price) {
        guard let user = userSession.currentUser else { return }
        Task {
            await barRepository.deletePrice(price, reportedBy: user)
        }
    }

    private func deleteGroup(_ group: PriceGroup) {
        guard let user = userSession.currentUser else { return }
        Task {
            await barRepository.deletePriceGroup(
                for: currentBar,
                drink: group.drink,
                size: group.size,
                brand: group.brand,
                deletedBy: user
            )
        }
    }

    private func handleBarReportTap() {
        showingBarReport = true
    }

    private func myDrinkRatingIcon(for group: PriceGroup) -> String {
        guard let user = userSession.currentUser else { return "star" }
        let hasRating = cachedDrinkRatings.contains {
            $0.barID == currentBar.id &&
            $0.drink == group.drink &&
            $0.brand == group.brand &&
            $0.size == group.size &&
            $0.ratedBy == user.id
        }
        return hasRating ? "star.fill" : "star"
    }
}
