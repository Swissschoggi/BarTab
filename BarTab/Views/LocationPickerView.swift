import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {

    @Binding var selectedCoordinate:
        CLLocationCoordinate2D?

    @Binding var address: String

    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var locationService: LocationService

    @State private var region =
        MKCoordinateRegion(
            center:
                CLLocationCoordinate2D(
                    latitude: 47.3769,
                    longitude: 8.5417
                ),
            span:
                MKCoordinateSpan(
                    latitudeDelta: 0.01,
                    longitudeDelta: 0.01
                )
        )

    var body: some View {

        NavigationView {

            ZStack {

                Map(
                    coordinateRegion:
                        $region,
                    showsUserLocation:
                        true
                )

                Image(
                    systemName:
                        "mappin.circle.fill"
                )
                .font(
                    .system(size: 40)
                )
                .foregroundColor(
                    .barTabPrimary
                )

                VStack {

                    Spacer()

                    Button {

                        selectLocation()

                    } label: {

                        HStack {

                            Image(
                                systemName:
                                    "checkmark"
                            )

                            Text(
                                "Use this location"
                            )
                            .fontWeight(
                                .semibold
                            )
                        }
                        .foregroundColor(
                            .white
                        )
                        .padding()
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .background(
                            Color.barTabPrimary
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: BarTabRadius.card,
                                style: .continuous
                            )
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle(
                "Choose Location"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .onAppear {

                locationService
                    .requestPermission()

                if let location =
                    locationService.location {

                    region =
                        MKCoordinateRegion(
                            center:
                                location
                                    .coordinate,
                            span:
                                MKCoordinateSpan(
                                    latitudeDelta:
                                        0.01,
                                    longitudeDelta:
                                        0.01
                                )
                        )
                }
            }
        }
    }

    private func selectLocation() {

        let coordinate =
            region.center

        selectedCoordinate =
            coordinate

        reverseGeocode(
            coordinate:
                coordinate
        )

        dismiss()
    }

    private func reverseGeocode(
        coordinate:
            CLLocationCoordinate2D
    ) {

        let location =
            CLLocation(
                latitude:
                    coordinate.latitude,
                longitude:
                    coordinate.longitude
            )

        CLGeocoder()
            .reverseGeocodeLocation(
                location
            ) { placemarks, error in

                guard
                    error == nil,
                    let placemark =
                        placemarks?.first
                else {
                    return
                }

                let parts = [
                    placemark.name,
                    placemark.locality,
                    placemark.country
                ]
                .compactMap {
                    $0
                }

                DispatchQueue.main.async {

                    if !parts.isEmpty {

                        address =
                            parts.joined(
                                separator: ", "
                            )
                    }
                }
            }
    }
}
