import CoreLocation
import Foundation
import Combine

final class LocationService: NSObject, ObservableObject {

    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    @Published private(set) var location: CLLocation?

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // If permission was already granted in a previous session,
        // `didChangeAuthorization` won't fire again, so kick off
        // updates right away.
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }


    func requestPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            break
        }
    }


    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
}


extension LocationService: CLLocationManagerDelegate {

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latestLocation = locations.last else {
            return
        }

        DispatchQueue.main.async {
            self.location = latestLocation
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()

        default:
            break
        }
    }
}
