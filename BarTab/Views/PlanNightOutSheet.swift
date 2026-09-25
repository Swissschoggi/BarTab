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

    private var canCreate: Bool {
        !titleText.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(String(localized: "Name your night out"), text: $titleText)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(String(localized: "Title"))
                }

                Section {
                    Toggle(String(localized: "Set a date"), isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker(String(localized: "When"), selection: $date)
                    }
                } header: {
                    Text(String(localized: "When"))
                }

                Section {
                    if crawlBars.isEmpty {
                        Button {
                            generateCrawl()
                        } label: {
                            Label(String(localized: "Generate a crawl"), systemImage: "figure.walk.circle.fill")
                        }
                    } else {
                        ForEach(Array(crawlBars.enumerated()), id: \.element.id) { index, bar in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.barTabTiny)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.barTabPrimary)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(bar.name)
                                        .font(.barTabBody)
                                    Text(bar.address)
                                        .font(.barTabTiny)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Button {
                            generateCrawl()
                        } label: {
                            Label(String(localized: "Shuffle stops"), systemImage: "shuffle")
                        }
                    }
                } header: {
                    Text(String(localized: "Crawl (optional)"))
                } footer: {
                    Text(String(localized: "A 3-bar route you'll tackle together."))
                }
            }
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
    }

    private func generateCrawl() {
        let allBars = barRepository.bars
        guard allBars.count >= 3 else {
            crawlBars = allBars
            return
        }

        if let userLocation = locationService.location {
            let sorted = allBars.sorted {
                DistanceService.distance(from: userLocation, to: $0)
                    < DistanceService.distance(from: userLocation, to: $1)
            }
            crawlBars = Array(sorted.prefix(10).shuffled().prefix(3))
        } else {
            crawlBars = Array(allBars.shuffled().prefix(3))
        }
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
