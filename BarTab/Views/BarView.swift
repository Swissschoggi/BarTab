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
    @State private var ratingDrinkGroup: PriceGroup?
    @State private var showingDrinkRating = false
    @State private var alertDrinkGroup: PriceGroup?
    @State private var showingPriceAlert = false
    @State private var comparisonGroup: PriceGroup?

    // Cached from @Published   never read barRepository directly in body
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

        // Auto-hide groups with enough unreviewed reports (pending admin review).
        let visibleGroups = groups.filter { group in
            let key = barRepository.priceGroupKey(
                drink: group.drink,
                size: group.size,
                brand: group.brand,
                style: group.style,
                serving: group.serving
            )
            return !barRepository.isAutoHidden(targetID: key)
        }

        return visibleGroups.sorted {
            averageAmount(for: $0) < averageAmount(for: $1)
        }
    }

    var body: some View {
        attachModals(
            to: ScrollView {
                content
                    .padding(.horizontal, BarTabSpacing.md)
                    .padding(.top, BarTabSpacing.sm)
                    .padding(.bottom, 32)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 0) {
            barHeader
                .padding(.bottom, BarTabSpacing.md)

            if userSession.currentUser != nil {
                quickActionsRow
                    .padding(.bottom, BarTabSpacing.lg)
            }

            compactInfoRow
                .padding(.bottom, BarTabSpacing.lg)

            menuSection

            directionsButton
                .padding(.top, BarTabSpacing.lg)
        }
    }

    // MARK: - Header

    private var barHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(currentBar.address)
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let location = locationService.location {
                    Image(systemName: "location.fill")
                    Text(DistanceService.formattedDistance(from: location, to: currentBar))
                }

                if let priceLevel = priceLevelString {
                    Text("·")
                        .foregroundColor(.barTabSecondary)
                    Text(priceLevel)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .font(.barTabTiny)
            .foregroundColor(.barTabSecondary)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        let busyCount = barRepository.busyCount(for: currentBar.id)
        let hasCheckedIn = userSession.currentUser.map {
            barRepository.hasUserCheckedIn(barID: currentBar.id, userID: $0.id)
        } ?? false

        return HStack(spacing: 8) {
            Button {
                Task {
                    guard let user = userSession.currentUser else { return }
                    let ok: Bool

                    if hasCheckedIn {
                        ok = await barRepository.uncheckIn(bar: currentBar, user: user)
                    } else {
                        ok = await barRepository.checkIn(bar: currentBar, user: user)
                        if ok {
                            HapticEngine.success()
                            toastCenter.show("You're here have fun! 🍻", kind: .success)
                        }
                    }

                    if !ok {
                        toastCenter.show("Couldn't update right now", kind: .error)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: hasCheckedIn ? "checkmark.circle.fill" : "figure.walk")
                    Text(hasCheckedIn ? "You're here" : "I'm here")

                    if busyCount > 0 {
                        Text("· \(busyCount)")
                            .opacity(0.72)
                    }
                }
                .font(.barTabSmall)
                .fontWeight(.semibold)
                .foregroundColor(hasCheckedIn ? .barTabSuccess : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    hasCheckedIn
                        ? Color.barTabSuccess.opacity(0.10)
                        : Color.barTabPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                .overlay {
                    if hasCheckedIn {
                        RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                            .stroke(Color.barTabSuccess.opacity(0.25), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                showingAddPrice = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                    Text("Add price")
                }
                .font(.barTabSmall)
                .fontWeight(.semibold)
                .foregroundColor(.barTabPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.barTabPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Compact info

    private var compactInfoRow: some View {
        let attributes = barRepository.allAttributeConsensus(for: currentBar, currentUser: userSession.currentUser)
        return HStack(spacing: 6) {
            ForEach(attributes.prefix(4)) { attr in
                ConsensusChip(attribute: attr) {
                    selectedAttribute = attr
                    showingAttributeDetail = true
                }
            }

            if attributes.count > 4 {
                Button {
                    showingAllAttributes = true
                } label: {
                    Text("+\(attributes.count - 4) more")
                        .font(.barTabTiny)
                        .fontWeight(.medium)
                        .foregroundColor(.barTabSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.barTabSurface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.barTabCardBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Rate button
            Button {
                showingRateBar = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "star")
                    Text("Rate")
                }
                .font(.barTabTiny)
                .fontWeight(.semibold)
                .foregroundColor(.barTabAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.barTabAccent.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 1)
    }

    @State private var selectedAttribute: BarAttribute?
    @State private var showingAttributeDetail = false
    @State private var showingAllAttributes = false

    // Consensus chip showing community consensus with confirm/report action
    private struct ConsensusChip: View {
        let attribute: BarAttribute
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: attribute.key.icon)
                        .font(.barTabTiny)
                    if let value = attribute.consensusValue {
                        Text(value)
                            .font(.barTabTiny)
                            .fontWeight(.medium)
                        // Confidence indicator
                        if attribute.consensusConfidence > 0 {
                            Text("\(attribute.consensusConfidence)%")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(confidenceColor(attribute.consensusConfidence))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(confidenceColor(attribute.consensusConfidence).opacity(0.15))
                                .clipShape(Capsule())
                        }
                    } else {
                        Text("Unknown")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSecondary)
                    }
                }
                .foregroundColor(attribute.consensusValue != nil ? .barTabPrimary : .barTabSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    attribute.consensusValue != nil
                    ? Color.barTabPrimary.opacity(0.1)
                    : Color.barTabSurface
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        attribute.consensusValue != nil
                        ? Color.barTabCardBorder
                        : Color.barTabCardBorder,
                        lineWidth: 0.5
                    )
                )
            }
            .buttonStyle(.plain)
        }

        func confidenceColor(_ pct: Int) -> Color {
            switch pct {
            case 80...100: return .barTabSuccess
            case 50..<80: return .barTabWarning
            default: return .barTabDanger
            }
        }
    }

    // MARK: - Directions

    private var directionsButton: some View {
        Button {
            openDirections()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                Text("Directions")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.barTabTiny)
            }
            .font(.barTabSmall)
            .foregroundColor(.barTabSecondary)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Menu")
                    .font(.barTabHeading)
                    .fontWeight(.bold)

                Spacer()

                if let fetchedAt = barRepository.lastFetchedAt {
                    Text("Updated \(fetchedAt.relativeFormatted)")
                        .font(.barTabTiny)
                        .foregroundColor(.barTabSecondary)
                }
            }
            .padding(.bottom, 2)

            if groupedPrices.isEmpty {
                emptyPricesView
            } else {
                VStack(spacing: 0) {
                    ForEach(Drink.allCases.filter { drink in
                        groupedPrices.contains { $0.drink == drink }
                    }) { drink in
                        drinkCategory(drink)
                    }
                }
            }
        }
    }

    private func drinkCategory(_ drink: Drink) -> some View {
        let groups = groupedPrices.filter { $0.drink == drink }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedDrinkCategories.formSymmetricDifference([drink])
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: drink.icon)
                        .font(.barTabSmall)
                        .foregroundColor(.barTabPrimary)
                        .frame(width: 22)

                    Text(drink.displayName.uppercased())
                        .font(.barTabTiny)
                        .fontWeight(.bold)
                        .tracking(0.7)
                        .foregroundColor(.barTabSecondary)

                    Text("\(groups.count)")
                        .font(.barTabTiny)
                        .foregroundColor(.barTabSecondary.opacity(0.8))

                    Spacer()

                    Image(systemName: expandedDrinkCategories.contains(drink)
                          ? "chevron.up"
                          : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.barTabSecondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if expandedDrinkCategories.contains(drink) {
                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        priceGroupRow(group)
                    }
                }
            }

            Divider()
                .opacity(0.65)
        }
    }

    private func priceGroupRow(_ group: PriceGroup) -> some View {
        let isExpanded = expandedGroupID == group.id
        let groupKey = "\(group.drink)-\(group.size)-\(group.brand ?? "")-\(group.style ?? "")-\(group.serving?.rawValue ?? "")"
        let isFlagged = cachedReports.contains { $0.targetID == groupKey }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedGroupID = isExpanded ? nil : group.id
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            if let brand = group.brand, !brand.isEmpty {
                                Text(brand)
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            } else {
                                Text(group.drink.displayName)
                                    .font(.barTabBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.barTabText)
                            }

                            if isFlagged {
                                Image(systemName: "flag.fill")
                                    .font(.barTabTiny)
                                    .foregroundColor(.barTabWarning)
                            }
                        }

                        HStack(spacing: 4) {
                            Text(group.size.displayName)

                            if let style = group.style, !style.isEmpty {
                                Text("·")
                                Text(style)
                            }

                            if let serving = group.serving {
                                Text("·")
                                Text(serving.displayName)
                            }
                        }
                        .font(.barTabTiny)
                        .foregroundColor(.barTabSecondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Currency.defaultCurrency.symbol)\(Decimal(averageAmount(for: group)).formattedAmount)")
                            .font(.barTabBody)
                            .fontWeight(.bold)
                            .foregroundColor(.barTabPrimary)

                        if group.prices.count > 1 {
                            Text("\(group.prices.count) reports")
                                .font(.barTabTiny)
                                .foregroundColor(.barTabSecondary)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.barTabSecondary)
                        .frame(width: 14)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 9) {
                    if group.prices.count > 1 {
                        PriceTrendChart(prices: group.prices)
                            .frame(height: 110)
                            .padding(.top, 2)
                    } else {
                        Text("One reported price")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSecondary)
                    }

                    ForEach(group.prices) { price in
                        individualPriceRow(price)
                    }

                    HStack {
                        Button {
                            ratingDrinkGroup = group
                            showingDrinkRating = true
                        } label: {
                            Label("Rate", systemImage: myDrinkRatingIcon(for: group))
                                .font(.barTabTiny)
                                .fontWeight(.semibold)
                        }

                        Button {
                            alertDrinkGroup = group
                            showingPriceAlert = true
                        } label: {
                            Label("Alert", systemImage: "bell")
                                .font(.barTabTiny)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Menu {
                            Button {
                                comparisonGroup = group
                            } label: {
                                Label("Compare prices", systemImage: "barchart.xaxis.2")
                            }

                            Button {
                                pendingReportGroup = group
                                showingPriceReport = true
                            } label: {
                                Label("Report price", systemImage: "exclamationmark.circle")
                            }

                            if let user = userSession.currentUser, user.isAdmin {
                                Button(role: .destructive) {
                                    pendingDeleteGroup = group
                                    showingDeleteGroupConfirmation = true
                                } label: {
                                    Label("Delete all", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .foregroundColor(.barTabPrimary)
                    .padding(.bottom, 8)
                }
                .padding(.leading, 34)
                .transition(.opacity)
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

    private func individualPriceRow(_ price: Price) -> some View {
        let userID = userSession.currentUser?.id
        let isMine = userID == price.reportedBy
        let hasVerified = userID.map {
            barRepository.hasUserVerified(priceID: price.id, userID: $0)
        } ?? false
        let verifyCount = barRepository.verificationCount(for: price.id)
        let converted = ExchangeRateService.shared.convert(
            price.amount,
            from: price.currency,
            to: Currency.defaultCurrency.rawValue
        )
        let showOriginal = price.currency != Currency.defaultCurrency.rawValue

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("\(Currency.defaultCurrency.symbol)\(converted.formattedAmount)")
                        .font(.barTabSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabText)

                    if verifyCount > 0 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSuccess)

                        Text("\(verifyCount)")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSuccess)
                    }
                }

                HStack(spacing: 5) {
                    Text(price.reportedAt.relativeFormatted)

                    if showOriginal {
                        Text("· \(price.formattedAmount) \(price.currency)")
                    }
                }
                .font(.barTabTiny)
                .foregroundColor(.barTabSecondary)
            }

            Spacer()

            if !isMine {
                Button {
                    guard let user = userSession.currentUser else { return }
                    Task {
                        let ok: Bool

                        if hasVerified {
                            ok = await barRepository.unverifyPrice(price, user: user)
                            if ok {
                                HapticEngine.lightTap()
                                toastCenter.show("Verification removed", kind: .info)
                            }
                        } else {
                            ok = await barRepository.verifyPrice(price, user: user)
                            if ok {
                                HapticEngine.lightTap()
                                toastCenter.show("Thanks for confirming this price!", kind: .success)
                            }
                        }

                        if !ok {
                            toastCenter.show("Couldn't update right now", kind: .error)
                        }
                    }
                } label: {
                    Image(systemName: hasVerified
                          ? "checkmark.circle.fill"
                          : "checkmark.circle")
                        .font(.barTabBody)
                        .foregroundColor(hasVerified ? .barTabSuccess : .barTabSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    hasVerified
                        ? "Remove your verification"
                        : "Confirm this price is still accurate"
                )
            }

            if isMine {
                Button {
                    pendingDeletePrice = price
                    showingDeletePriceConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.barTabSmall)
                        .foregroundColor(.barTabDanger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete price")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.barTabPrimary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))
        .contextMenu {
            if !isMine {
                Button {
                    guard let user = userSession.currentUser else { return }
                    Task {
                        if hasVerified {
                            _ = await barRepository.unverifyPrice(price, user: user)
                        } else {
                            _ = await barRepository.verifyPrice(price, user: user)
                        }
                    }
                } label: {
                    Label(
                        hasVerified ? "Remove my verification" : "Confirm this price",
                        systemImage: hasVerified ? "xmark.circle" : "checkmark.circle"
                    )
                }
            }

            if isMine {
                Button(role: .destructive) {
                    pendingDeletePrice = price
                    showingDeletePriceConfirmation = true
                } label: {
                    Label("Delete my price", systemImage: "trash")
                }
            }
        }
    }

    private var emptyPricesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No prices yet")
                .font(.barTabBody)
                .fontWeight(.semibold)

            Text("Be the first to add a drink price at this bar.")
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)

            if userSession.currentUser != nil {
                Button {
                    showingAddPrice = true
                } label: {
                    Text("Add the first price")
                        .font(.barTabSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabPrimary)
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 22)
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

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                HapticEngine.impact()
                withAnimation(.easeInOut(duration: 0.2)) {
                    barRepository.toggleFavorite(currentBar)
                }
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .foregroundColor(.barTabPrimary)
            }
            .accessibilityLabel(
                isFavorited ? "Remove from favorites" : "Add to favorites"
            )

            Menu {
                ShareLink(
                    item: DeepLink.bar(currentBar.id),
                    subject: Text(currentBar.name),
                    message: Text(shareText)
                ) {
                    Label("Share Bar", systemImage: "square.and.arrow.up")
                }

                Button {
                    handleBarReportTap()
                } label: {
                    Label(
                        hasReported ? "Bar Reported" : "Report Bar",
                        systemImage: hasReported ? "flag.fill" : "flag"
                    )
                }

                if canDeleteBar {
                    Divider()

                    Button {
                        showingEditBar = true
                    } label: {
                        Label("Edit Bar", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteBarConfirmation = true
                    } label: {
                        Label("Delete Bar", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.barTabSecondary)
            }
            .accessibilityLabel("More options")
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
            .sheet(isPresented: $showingAttributeDetail) {
                if let attr = selectedAttribute,
                   let user = userSession.currentUser {
                    AttributeDetailSheet(
                        bar: currentBar,
                        attribute: attr,
                        currentUser: user
                    )
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
                }
            }
            .sheet(isPresented: $showingAllAttributes) {
                AllAttributesSheet(
                    bar: currentBar,
                    currentUser: userSession.currentUser
                )
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
            }
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

        // Convert each report to the user's default currency first, so
        // prices entered in different currencies average correctly.
        let target = Currency.defaultCurrency.rawValue
        let total = group.prices.reduce(Decimal(0)) { partial, price in
            partial + ExchangeRateService.shared.convert(
                price.amount,
                from: price.currency,
                to: target
            )
        }
        let count = Decimal(group.prices.count)
        return NSDecimalNumber(decimal: total / count).doubleValue
    }

    private func priceLevelTitle(_ level: String) -> String {
        switch level.count {
        case 1: return String(localized: "Budget-friendly")
        case 2: return String(localized: "Moderate")
        case 3: return String(localized: "Pricey")
        default: return String(localized: "Premium")
        }
    }
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
        toastCenter.show("Reported   thanks for helping keep BarTab accurate.", kind: .success)
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
        toastCenter.show("Reported   thanks for helping keep BarTab accurate.", kind: .success)
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
