import SwiftUI
import MapKit
import CoreLocation

struct AddBarView: View {

    /// Called with the newly created bar right before this view
    /// dismisses, so a presenting view (e.g. the map) can jump to it.
    var onBarAdded: ((Bar) -> Void)? = nil

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @StateObject private var searchService = PlaceSearchService()

    @State private var duplicateBars: [Bar] = []
    @State private var showingDuplicateWarning = false

    @State private var name = ""
    @State private var address = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    @State private var showingLocationPicker = false
    @State private var smokingFriendly = false
    @State private var outdoorSeating = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {


                HStack(spacing: BarTabSpacing.sm) {

                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.barTabPrimary)

                    TextField(
                        "Search for a bar or place",
                        text: Binding(
                            get: {
                                searchService.query
                            },
                            set: { value in
                                searchService.updateQuery(value)
                            }
                        )
                    )
                    .textFieldStyle(.plain)

                    if !searchService.query.isEmpty {
                        Button {
                            searchService.updateQuery("")
                            searchService.clearResults()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color.barTabCardFill)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: BarTabRadius.control,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: BarTabRadius.control,
                        style: .continuous
                    )
                    .stroke(Color.barTabPrimary.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top)


                if !searchService.results.isEmpty {

                    ScrollView {
                        LazyVStack(
                            alignment: .leading,
                            spacing: 0
                        ) {

                            ForEach(
                                searchService.results,
                                id: \.self
                            ) { result in

                                Button {
                                    selectPlace(result)
                                } label: {

                                    HStack(spacing: BarTabSpacing.sm) {

                                        Image(
                                            systemName: "mappin.circle.fill"
                                        )
                                        .font(.barTabHeading)
                                        .foregroundColor(.barTabPrimary)

                                        VStack(
                                            alignment: .leading,
                                            spacing: 3
                                        ) {

                                            Text(result.title)
                                                .font(.barTabHeading)
                                                .foregroundColor(.primary)

                                            Text(result.subtitle)
                                                .font(.barTabBody)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, 58)
                            }
                        }
                    }


                } else if selectedCoordinate == nil {

                    VStack(spacing: BarTabSpacing.sm) {

                        Spacer()

                        Image(systemName: "building.2")
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)

                        Text("Find your bar")
                            .font(.barTabHeading)
                            .fontWeight(.semibold)

                        Text(
                            "Search for a bar, pub, cafe or other place."
                        )
                        .font(.barTabBody)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)

                        Spacer()
                    }


                } else {

                    ScrollView {
                        VStack(
                            alignment: .leading,
                            spacing: 20
                        ) {

                            selectedPlaceCard

                            barDetailsCard

                            Button {
                                showingLocationPicker = true
                            } label: {

                                HStack {

                                    Image(
                                        systemName: "mappin.and.ellipse"
                                    )

                                    Text("Adjust location")

                                    Spacer()

                                    Image(
                                        systemName: "chevron.right"
                                    )
                                }
                                .foregroundColor(.barTabPrimary)
                                .barTabCard(cornerRadius: BarTabRadius.control)
                            }

                            Button {
                                addBar()
                            } label: {

                                Text("Add Bar")
                                    .font(.barTabHeading)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .barTabPrimaryButton()
                            }
                            .disabled(!canCreateBar)
                            .opacity(canCreateBar ? 1 : 0.5)
                        }
                        .padding()
                    }
                }
            }
            .background(
                Color.barTabBackground
                    .ignoresSafeArea()
            )
            .navigationTitle("Add a Bar")
            .navigationBarTitleDisplayMode(.inline)


            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    selectedCoordinate: $selectedCoordinate,
                    address: $address
                )
            }

            .alert(
                "Bar may already exist",
                isPresented: $showingDuplicateWarning
            ) {

                Button("Add Anyway") {
                    duplicateBars.removeAll()
                }

                Button("Cancel", role: .cancel) {
                    clearSelection()
                }

            } message: {

                VStack {
                    Text(
                        "We found a bar nearby that may be the same place:"
                    )

                    ForEach(duplicateBars) { bar in
                        Text("• \(bar.name)")
                    }

                    Text(
                        "\nPlease check before adding a duplicate."
                    )
                }
            }
        }
    }


    private var selectedPlaceCard: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack {

                Image(
                    systemName: "checkmark.circle.fill"
                )
                .foregroundColor(.barTabPrimary)

                Text("Selected place")
                    .font(.barTabHeading)

                Spacer()
            }

            Text(name)
                .font(.barTabHeading)
                .fontWeight(.semibold)

            Text(address)
                .font(.barTabBody)
                .foregroundColor(.secondary)
        }
        .barTabCard()
    }


    private var barDetailsCard: some View {

        VStack(alignment: .leading, spacing: 16) {

            Toggle(isOn: $smokingFriendly) {
                Label(
                    "Smoking friendly",
                    systemImage: "smoke.fill"
                )
                .foregroundColor(.primary)
            }
            .tint(.barTabPrimary)

            Divider()

            Toggle(isOn: $outdoorSeating) {
                Label(
                    "Outdoor seating",
                    systemImage: "sun.max.fill"
                )
                .foregroundColor(.primary)
            }
            .tint(.barTabPrimary)
        }
        .barTabCard()
    }


    private var canCreateBar: Bool {

        !name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        &&
        !address
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        &&
        selectedCoordinate != nil
    }


    private func selectPlace(
        _ completion: MKLocalSearchCompletion
    ) {

        searchService.clearResults()

        let request = MKLocalSearch.Request(
            completion: completion
        )

        let search = MKLocalSearch(
            request: request
        )

        search.start { response, error in

            guard
                error == nil,
                let item = response?.mapItems.first
            else {
                DispatchQueue.main.async {
                    toastCenter.show("Could not find location", kind: .error)
                }
                return
            }

            DispatchQueue.main.async {

                name =
                    item.name
                    ?? completion.title

                address =
                    formattedAddress(
                        from: item.placemark
                    )

                selectedCoordinate =
                    item.placemark.coordinate

                let coordinate =
                    item.placemark.coordinate

                duplicateBars =
                    barRepository.nearbyBars(
                        coordinate: coordinate,
                        radius: 100
                    )

                if !duplicateBars.isEmpty {
                    showingDuplicateWarning = true
                }

                searchService.updateQuery("")
            }
        }
    }

    // MARK: - Address formatting

    private func formattedAddress(
        from placemark: CLPlacemark
    ) -> String {

        var parts: [String] = []

        if let street = placemark.thoroughfare {

            if let number = placemark.subThoroughfare {
                parts.append("\(street) \(number)")
            } else {
                parts.append(street)
            }
        }

        if let city = placemark.locality {
            parts.append(city)
        }

        if let postalCode = placemark.postalCode {

            if !parts.contains(postalCode) {
                parts.append(postalCode)
            }
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Add bar

    private func addBar() {

        guard let user = userSession.currentUser else {

            toastCenter.show(
                "You must be logged in to add a bar.",
                kind: .error
            )
            return
        }

        guard let coordinate = selectedCoordinate else {

            toastCenter.show(
                "Please select a location.",
                kind: .error
            )
            return
        }

        let trimmedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let trimmedAddress =
            address.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedName.isEmpty else {

            toastCenter.show(
                "Please select a place.",
                kind: .error
            )
            return
        }

        Task {
            let saved = await barRepository.addBar(
                name: trimmedName,
                address: trimmedAddress,
                coordinate: coordinate,
                smokingFriendly: smokingFriendly,
                outdoorSeating: outdoorSeating,
                createdBy: user
            )

            guard let saved else {
                toastCenter.show(
                    "Could not save the bar",
                    kind: .error
                )
                return
            }

            onBarAdded?(saved)
            dismiss()
        }
    }

    // MARK: - Clear selection

    private func clearSelection() {

        name = ""
        address = ""
        selectedCoordinate = nil
        duplicateBars.removeAll()
        smokingFriendly = false
        outdoorSeating = false

        searchService.updateQuery("")
        searchService.clearResults()
    }
}
