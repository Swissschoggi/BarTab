import SwiftUI
import CoreLocation

/// Creates a "night out" for a group: title, optional date, and a
/// shared crawl (generated near you, or shuffled when no location).
struct PlanNightOutSheet: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var titleText = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var crawlBars: [Bar] = []
    @State private var isSaving = false
    @State private var showingLocationPicker = false
    @State private var showingRouteMap = false

    /// A user-chosen crawl origin. `nil` means "my current location".
    @State private var crawlOrigin: CLLocationCoordinate2D?
    @State private var originName: String = ""

    private var originLocation: CLLocation? {
        if let crawlOrigin {
            return CLLocation(latitude: crawlOrigin.latitude, longitude: crawlOrigin.longitude)
        }
        return locationService.location
    }

    private var originLabel: String {
        if crawlOrigin != nil {
            return originName.isEmpty ? String(localized: "Chosen place") : originName
        }
        return String(localized: "My location")
    }

    private var canCreate: Bool {
        !titleText.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    // Title Section
                    selectorGroup(title: String(localized: "TITLE")) {
                        TextField(String(localized: "Name your night out"), text: $titleText)
                            .textInputAutocapitalization(.words)
                            .padding(.vertical, 12)
                            .padding(.horizontal, BartapSpacing.md)
                            .background(Color.BartapSurface)
                            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                                    .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                            )
                    }

                    // Date Section
                    selectorGroup(title: String(localized: "WHEN")) {
                        VStack(spacing: BartapSpacing.sm) {
                            Toggle(String(localized: "Set a date"), isOn: $hasDate.animation())
                                .tint(.BartapPrimary)

                            if hasDate {
                                DatePicker(String(localized: "When"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, BartapSpacing.md)
                                    .background(Color.BartapSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                                    )
                            }
                        }
                    }

                    // Location Section
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text(String(localized: "SEARCHING NEAR"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        FlowLayout(spacing: BartapSpacing.xs) {
                            originPill(
                                title: String(localized: "My location"),
                                icon: "location.fill",
                                isSelected: crawlOrigin == nil
                            ) {
                                crawlOrigin = nil
                                originName = ""
                            }

                            originPill(
                                title: crawlOrigin == nil ? String(localized: "Choose a place…") : originLabel,
                                icon: crawlOrigin == nil ? "mappin.and.ellipse" : "mappin.circle.fill",
                                isSelected: crawlOrigin != nil
                            ) {
                                showingLocationPicker = true
                            }
                        }
                    }

                    // Crawl Section
                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        HStack {
                            Text(String(localized: "CRAWL"))
                                .font(.BartapCaption)
                                .foregroundColor(.BartapSecondary)

                            Spacer()

                            if !crawlBars.isEmpty {
                                Button {
                                    generateCrawl()
                                } label: {
                                    Label(String(localized: "Shuffle"), systemImage: "shuffle")
                                        .BartapPillButton()
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if crawlBars.isEmpty {
                            Button {
                                generateCrawl()
                            } label: {
                                Label(String(localized: "Generate a crawl"), systemImage: "figure.walk.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .BartapPrimaryButton()
                            }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(crawlBars.enumerated()), id: \.element.id) { index, bar in
                                    crawlRow(index: index, bar: bar)

                                    if index < crawlBars.count - 1 {
                                        Divider()
                                            .foregroundColor(.BartapCardBorder)
                                            .padding(.leading, 58)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                                    .fill(Color.BartapCardFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                                    .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                            )

                            HStack(spacing: BartapSpacing.sm) {
                                Button {
                                    generateCrawl()
                                } label: {
                                    Label(String(localized: "Shuffle"), systemImage: "shuffle")
                                        .BartapPillButton()
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showingRouteMap = true
                                } label: {
                                    Label(String(localized: "Show on map"), systemImage: "map.fill")
                                        .BartapPillButton()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .BartapCard()

                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.md)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "New Night Out"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Create")) {
                        Task { await create() }
                    }
                    .disabled(!canCreate)
                }
            }
            .onAppear {
                locationService.requestPermission()
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedCoordinate: $crawlOrigin,
                address: $originName
            )
            .environmentObject(locationService)
        }
        .sheet(isPresented: $showingRouteMap) {
            CrawlRouteView(stops: crawlBars)
                .environmentObject(locationService)
        }
    }

    private func originPill(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.BartapCaption)
                Text(title)
                    .font(.BartapCaption)
                    .lineLimit(1)
            }
            .padding(.horizontal, BartapSpacing.sm)
            .padding(.vertical, 8)
            .background(isSelected ? Color.BartapPrimary : Color.BartapSurface)
            .foregroundColor(isSelected ? .white : .BartapText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.BartapCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func crawlRow(index: Int, bar: Bar) -> some View {
        HStack(spacing: BartapSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.BartapPrimary)
                    .frame(width: 30, height: 30)
                Text("\(index + 1)")
                    .font(.BartapBodySemibold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bar.name)
                    .font(.BartapBodySemibold)
                    .foregroundColor(.BartapText)
                    .lineLimit(1)

                Text(bar.address)
                    .font(.BartapCaption)
                    .foregroundColor(.BartapSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let popular = barRepository.popularAmbience(for: bar) {
                HStack(spacing: 3) {
                    Image(systemName: popular.icon)
                        .font(.BartapTiny)
                    Text(popular.displayName)
                        .font(.BartapTiny)
                }
                .BartapPillButton()
            }
        }
        .padding(.horizontal, BartapSpacing.md)
        .padding(.vertical, BartapSpacing.sm)
    }

    private func generateCrawl() {
        let allBars = barRepository.bars
        guard allBars.count >= 3 else {
            crawlBars = allBars
            return
        }

        guard let userLocation = originLocation else {
            crawlBars = Array(allBars.shuffled().prefix(3))
            return
        }

        let nearby = barRepository.nearbyBars(
            coordinate: userLocation.coordinate,
            radius: BarRepository.walkingCrawlRadius
        )
        .sorted {
            DistanceService.distance(from: userLocation, to: $0)
                < DistanceService.distance(from: userLocation, to: $1)
        }

        guard nearby.count >= 3 else {
            toastCenter.show(
                String(localized: "Not enough bars nearby to build a crawl."),
                kind: .info
            )
            return
        }

        crawlBars = Array(nearby.prefix(10).shuffled().prefix(3))
    }

    private func create() async {
        let title = titleText.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        isSaving = true
        do {
            let event = try await SupabaseClient.shared.createEvent(
                groupID: group.id,
                title: title,
                startsAt: hasDate ? date : nil
            )

            if !crawlBars.isEmpty {
                try await SupabaseClient.shared.replaceCrawlStops(
                    eventID: event.id,
                    barIDs: crawlBars.map(\.id)
                )
            }

            HapticEngine.success()
            toastCenter.show(String(localized: "Night out planned"), kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}

// MARK: - Subviews

private func selectorGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
        Text(title)
            .font(.BartapCaption)
            .foregroundColor(.BartapSecondary)
        content()
    }
}

struct PlanNightOutSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlanNightOutSheet(group: BarGroup(id: UUID(), name: "Test Group", createdBy: UUID(), createdAt: Date()))
            .environmentObject(BarRepository())
            .environmentObject(UserSession())
            .environmentObject(ToastCenter())
    }
}