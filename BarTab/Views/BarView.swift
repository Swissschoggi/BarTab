import SwiftUI
import MapKit

struct BarView: View {

    let bar: Bar
    let allowsDismissal: Bool

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var locationService = LocationService()

    @State private var showingAddPrice = false
    @State private var expandedGroupID: String?

    @State private var showingBarReport = false
    @State private var showingPriceReport = false
    @State private var pendingReportGroup: PriceGroup?
    @State private var showingReportConfirmation = false
    @State private var reportConfirmationText = ""
    @State private var showingAlreadyReported = false
    @State private var alreadyReportedText = ""

    @State private var showingDeleteBarConfirmation = false
    @State private var pendingDeletePrice: Price?
    @State private var showingDeletePriceConfirmation = false
    @State private var pendingDeleteGroup: PriceGroup?
    @State private var showingDeleteGroupConfirmation = false

    @State private var showingRateBar = false

    init(bar: Bar, allowsDismissal: Bool = false) {
        self.bar = bar
        self.allowsDismissal = allowsDismissal
    }

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
        attachModals(
            to: ScrollView {
                content
                    .padding()
            }
            .background(
                Color.barTabBackground
                    .ignoresSafeArea()
            )
            .navigationTitle(bar.name)
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
            spacing: 24
        ) {

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                Text(bar.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let location =
                    locationService.location {

                    Label(
                        DistanceService.formattedDistance(
                            from: location,
                            to: bar
                        ),
                        systemImage: "location.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            detailsSection

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
                openDirections()
            } label: {
                HStack {
                    Image(
                        systemName: "arrow.triangle.turn.up.right.diamond.fill"
                    )

                    Text("Get Directions")
                        .fontWeight(.semibold)

                    Spacer()

                    Image(
                        systemName: "arrow.up.right"
                    )
                }
                .foregroundColor(.barTabPrimary)
                .padding()
                .frame(
                    maxWidth: .infinity
                )
                .background(
                    Color.barTabPrimary.opacity(0.12)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
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
                .padding()
                .barTabPrimaryButton()
            }
        }
    }

    private var detailsSection: some View {

        let ambience = barRepository.averageAmbience(for: bar)
        let wine = barRepository.averageWineQuality(for: bar)

        return VStack(alignment: .leading, spacing: 14) {

            HStack {
                Label(
                    bar.smokingFriendly ? "Smoking friendly" : "No smoking",
                    systemImage: bar.smokingFriendly ? "smoke.fill" : "smoke"
                )
                .font(.subheadline)
                .foregroundColor(
                    bar.smokingFriendly ? .barTabPrimary : .secondary
                )

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ambience")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let ambience = ambience {
                        StarRatingSummaryView(
                            average: ambience.average,
                            count: ambience.count
                        )
                    } else {
                        Text("No ratings yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Wine selection")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let wine = wine {
                        StarRatingSummaryView(
                            average: wine.average,
                            count: wine.count
                        )
                    } else {
                        Text("No ratings yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    showingRateBar = true
                } label: {
                    Label("Rate this bar", systemImage: "star")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabPrimary)
                }
                .padding(.top, 2)
            }
        }
        .barTabCard()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        if allowsDismissal {

            ToolbarItem(
                placement: .navigationBarLeading
            ) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }

        ToolbarItem(
            placement: .navigationBarTrailing
        ) {
            Button {
                withAnimation(
                    .easeInOut(duration: 0.2)
                ) {
                    barRepository.toggleFavorite(bar)
                }
            } label: {
                Image(
                    systemName:
                        barRepository.isFavorite(bar)
                        ? "heart.fill"
                        : "heart"
                )
                .foregroundColor(.barTabPrimary)
            }
        }

        ToolbarItem(
            placement: .navigationBarTrailing
        ) {
            ShareLink(
                item: shareText
            ) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.barTabPrimary)
            }
        }

        ToolbarItem(
            placement: .navigationBarTrailing
        ) {
            Button {
                handleBarReportTap()
            } label: {
                Image(
                    systemName: currentUserReportedBar
                    ? "flag.fill"
                    : "flag"
                )
                .foregroundColor(.barTabPrimary)
            }
        }

        if canDeleteBar {

            ToolbarItem(
                placement: .navigationBarTrailing
            ) {
                Button {
                    showingDeleteBarConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
        private func attachModals<V: View>(
        to view: V
    ) -> some View {
        view
            .sheet(
                isPresented: $showingAddPrice
            ) {
                AddPriceView(bar: bar)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
            }
            .sheet(
                isPresented: $showingRateBar
            ) {
                let mine = userSession.currentUser.flatMap {
                    barRepository.myRating(for: bar, by: $0)
                }

                RateBarSheet(
                    bar: bar,
                    initialAmbience: mine?.ambience,
                    initialWineQuality: mine?.wineQuality
                )
                .environmentObject(barRepository)
                .environmentObject(userSession)
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
                Text(
                    "Tell us why this bar looks wrong."
                )
            }
            .confirmationDialog(
                "Report this price?",
                isPresented: $showingPriceReport,
                titleVisibility: .visible
            ) {
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) {
                        guard let group = pendingReportGroup else {
                            return
                        }
                        reportPriceGroup(group, reason: reason)
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Tell us why this price looks wrong."
                )
            }
            .alert(
                "Thanks for your report",
                isPresented: $showingReportConfirmation
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(reportConfirmationText)
            }
            .alert(
                "Already reported",
                isPresented: $showingAlreadyReported
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alreadyReportedText)
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
                Text(
                    "This removes the bar and all of its prices. This can't be undone."
                )
            }
            .confirmationDialog(
                "Delete this price?",
                isPresented: $showingDeletePriceConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let price = pendingDeletePrice else {
                        return
                    }
                    deletePrice(price)
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This removes this price report. This can't be undone."
                )
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
                    guard let group = pendingDeleteGroup else {
                        return
                    }
                    deleteGroup(group)
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This removes all prices for this drink at this bar. This can't be undone."
                )
            }
    }

    private func priceGroupRow(
        _ group: PriceGroup
    ) -> some View {

        let confidence = confidenceForGroup(group)
        let average = averageAmount(for: group)
        let change = group.prices.priceChange
        let isExpanded = expandedGroupID == group.id
        let isFlagged = barRepository.isPriceGroupFlagged(
            drink: group.drink,
            size: group.size,
            brand: group.brand
        )

        return VStack(
            alignment: .leading,
            spacing: 0
        ) {

            Button {

                withAnimation(
                    .easeInOut(duration: 0.2)
                ) {
                    expandedGroupID =
                        isExpanded ? nil : group.id
                }

            } label: {

                VStack(
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

                                if isFlagged {
                                    Image(
                                        systemName: "flag.fill"
                                    )
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                }

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
                                "\(average.formattedAmount) CHF"
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

                    HStack {

                        if let change = change {
                            trendBadge(change)
                        }

                        Spacer()

                        Label(
                            isExpanded
                            ? "Hide history"
                            : "Show history",
                            systemImage: isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {

                Divider()
                    .padding(.vertical, 12)

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text("Price history")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    PriceTrendChart(
                        prices: group.prices
                    )

                    ForEach(
                        group.prices.sorted {
                            $0.reportedAt > $1.reportedAt
                        },
                        id: \.id
                    ) { price in

                        HStack {

                            Text(
                                "\(price.formattedAmount) \(price.currency)"
                            )
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                .barTabPrimary
                            )

                            Spacer()

                            Text(
                                relativeDate(
                                    price.reportedAt
                                )
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)

                            if canDeletePrice(price) {

                                Button {
                                    pendingDeletePrice = price
                                    showingDeletePriceConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    if canDeleteGroup(group) {

                        Divider()
                            .padding(.vertical, 4)

                        Button {
                            pendingDeleteGroup = group
                        } label: {
                            Label(
                                "Delete this drink",
                                systemImage: "trash"
                            )
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        }
                    }

                    Button {
                        pendingReportGroup = group
                        showingPriceReport = true
                    } label: {

                        let alreadyReported =
                            userSession.currentUser
                            .map {
                                barRepository.hasReported(
                                    group.id,
                                    by: $0
                                )
                            } ?? false

                        Label(
                            alreadyReported
                            ? "Reported — thanks"
                            : "Report this price",
                            systemImage: alreadyReported
                                ? "checkmark.circle"
                                : "flag"
                        )
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(
                            alreadyReported
                            ? .secondary
                            : .barTabPrimary
                        )
                    }
                }
            }
        }
        .barTabCard()
    }

    private func trendBadge(
        _ change: Double
    ) -> some View {

        let up = change >= 0
        let color: Color = up ? .green : .red

        return Label(
            "\(up ? "▲" : "▼") \(String(format: "%.1f%%", abs(change * 100)))",
            systemImage: up
                ? "arrow.up.right"
                : "arrow.down.right"
        )
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func relativeDate(
        _ date: Date
    ) -> String {

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short

        return formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }

    private var shareText: String {

        var text = "\(bar.name)\n\(bar.address)"

        let lines = groupedPrices.prefix(3).map { group in

            "• \(group.drink.displayName) " +
            "(\(group.size.displayName)) — " +
            "\(averageAmount(for: group).formattedAmount) CHF"
        }

        if !lines.isEmpty {
            text += "\n\nPrices:\n" + lines.joined(
                separator: "\n"
            )
        }

        return text
    }

    private var currentUserReportedBar: Bool {

        guard let user = userSession.currentUser else {
            return false
        }

        return barRepository.hasReported(
            bar.id.uuidString,
            by: user
        )
    }

    private func handleBarReportTap() {

        if currentUserReportedBar {
            alreadyReportedText =
                String(localized: "You've already reported this bar.")
            showingAlreadyReported = true
            return
        }

        showingBarReport = true
    }

    private func reportBar(reason: ReportReason) {

        guard let user = userSession.currentUser else {
            return
        }

        barRepository.reportBar(
            bar,
            reason: reason,
            reportedBy: user
        )

        reportConfirmationText = String(localized: "We'll review this bar and remove it if it doesn't belong.")
        showingReportConfirmation = true
    }

    private func reportPriceGroup(
        _ group: PriceGroup,
        reason: ReportReason
    ) {

        guard let user = userSession.currentUser else {
            return
        }

        barRepository.reportPriceGroup(
            drink: group.drink,
            size: group.size,
            brand: group.brand,
            reason: reason,
            reportedBy: user
        )

        reportConfirmationText = String(localized: "We'll review this price and correct it if it looks wrong.")
        showingReportConfirmation = true
    }

    private var canDeleteBar: Bool {
        guard let user = userSession.currentUser else {
            return false
        }

        return user.isAdmin || bar.createdBy == user.id
    }

    private func canDeletePrice(
        _ price: Price
    ) -> Bool {
        guard let user = userSession.currentUser else {
            return false
        }

        return user.isAdmin || price.reportedBy == user.id
    }

    private func canDeleteGroup(
        _ group: PriceGroup
    ) -> Bool {
        guard let user = userSession.currentUser else {
            return false
        }

        return user.isAdmin || group.prices.allSatisfy { price in
            price.reportedBy == user.id
        }
    }

    private func deleteBar() {

        guard let user = userSession.currentUser else {
            return
        }

        Task {
            await barRepository.deleteBar(
                bar,
                createdBy: user
            )
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func deletePrice(
        _ price: Price
    ) {

        guard let user = userSession.currentUser else {
            return
        }

        Task {
            await barRepository.deletePrice(
                price,
                reportedBy: user
            )
        }
    }

    private func deleteGroup(
        _ group: PriceGroup
    ) {

        guard let user = userSession.currentUser else {
            return
        }

        Task {
            await barRepository.deletePriceGroup(
                for: bar,
                drink: group.drink,
                size: group.size,
                brand: group.brand,
                deletedBy: user
            )
        }
    }

    private func openDirections() {

        let placemark = MKPlacemark(
            coordinate: bar.coordinate
        )

        let mapItem = MKMapItem(
            placemark: placemark
        )
        mapItem.name = bar.name

        mapItem.openInMaps(
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey:
                    MKLaunchOptionsDirectionsModeWalking
            ]
        )
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