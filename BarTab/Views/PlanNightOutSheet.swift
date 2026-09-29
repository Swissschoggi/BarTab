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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {

                    // Title Section
                    selectorGroup(title: String(localized: "TITLE")) {
                        TextField(String(localized: "Name your night out"), text: $titleText)
                            .textInputAutocapitalization(.words)
                            .padding(.vertical, 12)
                            .padding(.horizontal, BarTabSpacing.md)
                            .background(Color.barTabSurface)
                            .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                    .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                            )
                    }

                    // Date Section
                    selectorGroup(title: String(localized: "WHEN")) {
                        VStack(spacing: BarTabSpacing.sm) {
                            Toggle(String(localized: "Set a date"), isOn: $hasDate.animation())
                                .tint(.barTabPrimary)

                            if hasDate {
                                DatePicker(String(localized: "When"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, BarTabSpacing.md)
                                    .background(Color.barTabSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                            .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                                    )
                            }
                        }
                    }

                    // Location Section
                    VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
                        Text(String(localized: "SEARCHING NEAR"))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        FlowLayout(spacing: BarTabSpacing.xs) {
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
                    VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                        HStack {
                            Text(String(localized: "CRAWL"))
                                .font(.barTabCaption)
                                .foregroundColor(.barTabSecondary)

                            Spacer()

                            if !crawlBars.isEmpty {
                                Button {
                                    generateCrawl()
                                } label: {
                                    Label(String(localized: "Shuffle"), systemImage: "shuffle")
                                        .barTabPillButton()
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
                                    .barTabPrimaryButton()
                            }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(crawlBars.enumerated()), id: \.element.id) { index, bar in
                                    crawlRow(index: index, bar: bar)

                                    if index < crawlBars.count - 1 {
                                        Divider()
                                            .foregroundColor(.barTabCardBorder)
                                            .padding(.leading, 58)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                                    .fill(Color.barTabCardFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                                    .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                            )

                            HStack(spacing: BarTabSpacing.sm) {
                                Button {
                                    generateCrawl()
                                } label: {
                                    Label(String(localized: "Shuffle"), systemImage: "shuffle")
                                        .barTabPillButton()
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showingRouteMap = true
                                } label: {
                                    Label(String(localized: "Show on map"), systemImage: "map.fill")
                                        .barTabPillButton()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .barTabCard()

                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
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
                    .font(.barTabCaption)
                Text(title)
                    .font(.barTabCaption)
                    .lineLimit(1)
            }
            .padding(.horizontal, BarTabSpacing.sm)
            .padding(.vertical, 8)
            .background(isSelected ? Color.barTabPrimary : Color.barTabSurface)
            .foregroundColor(isSelected ? .white : .barTabText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func crawlRow(index: Int, bar: Bar) -> some View {
        HStack(spacing: BarTabSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.barTabPrimary)
                    .frame(width: 30, height: 30)
                Text("\(index + 1)")
                    .font(.barTabBodySemibold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bar.name)
                    .font(.barTabBodySemibold)
                    .foregroundColor(.barTabText)
                    .lineLimit(1)

                Text(bar.address)
                    .font(.barTabCaption)
                    .foregroundColor(.barTabSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let popular = barRepository.popularAmbience(for: bar) {
                HStack(spacing: 3) {
                    Image(systemName: popular.icon)
                        .font(.barTabTiny)
                    Text(popular.displayName)
                        .font(.barTabTiny)
                }
                .barTabPillButton()
            }
        }
        .padding(.horizontal, BarTabSpacing.md)
        .padding(.vertical, BarTabSpacing.sm)
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

struct PlanNightOutSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlanNightOutSheet(group: BarGroup(id: UUID(), name: "Test Group", createdAt: Date(), createdBy: UUID()))
            .environmentObject(BarRepository())
            .environmentObject(UserSession())
            .environmentObject(ToastCenter())
    }
}