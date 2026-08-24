import SwiftUI
import MapKit
import CoreLocation

struct AddBarView: View {

    /// Called with the newly created bar right before this view
    /// dismisses, so a presenting view (e.g. the map) can jump to it.
    var onBarAdded: ((Bar) -> Void)? = nil

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var searchService = PlaceSearchService()

    @State private var duplicateBars: [Bar] = []
    @State private var showingDuplicateWarning = false

    @State private var name = ""
    @State private var address = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    @State private var showingLocationPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    @State private var smokingFriendly = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {


                HStack(spacing: 10) {

                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

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
                .background(Color.barTabBackground)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
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

                                    HStack(spacing: 14) {

                                        Image(
                                            systemName: "mappin.circle.fill"
                                        )
                                        .font(.title3)
                                        .foregroundColor(.barTabPrimary)

                                        VStack(
                                            alignment: .leading,
                                            spacing: 3
                                        ) {

                                            Text(result.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text(result.subtitle)
                                                .font(.subheadline)
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

                    VStack(spacing: 14) {

                        Spacer()

                        Image(systemName: "building.2")
                            .font(.system(size: 45))
                            .foregroundStyle(.barTabPrimary)

                        Text("Find your bar")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(
                            "Search for a bar, pub, cafe or other place."
                        )
                        .font(.subheadline)
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
                                .barTabCard(cornerRadius: 14)
                            }

                            Button {
                                addBar()
                            } label: {

                                Text("Add Bar")
                                    .font(.headline)
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
                "Couldn't add bar",
                isPresented: $showingError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
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
                    .font(.headline)

                Spacer()
            }

            Text(name)
                .font(.title3)
                .fontWeight(.semibold)

            Text(address)
                .font(.subheadline)
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

            errorMessage =
                "You must be logged in to add a bar."

            showingError = true
            return
        }

        guard let coordinate = selectedCoordinate else {

            errorMessage =
                "Please select a location."

            showingError = true
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

            errorMessage =
                "Please select a place."

            showingError = true
            return
        }

        Task {
            let saved = await barRepository.addBar(
                name: trimmedName,
                address: trimmedAddress,
                coordinate: coordinate,
                smokingFriendly: smokingFriendly,
                createdBy: user
            )

            guard let saved = saved else {
                self.errorMessage =
                    "Could not save the bar. "
                    + "Check your connection and try again."
                self.showingError = true
                return
            }

            onBarAdded?(saved)
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Clear selection

    private func clearSelection() {

        name = ""
        address = ""
        selectedCoordinate = nil
        duplicateBars.removeAll()
        smokingFriendly = false

        searchService.updateQuery("")
        searchService.clearResults()
    }
}
