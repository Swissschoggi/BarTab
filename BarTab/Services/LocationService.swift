import CoreLocation
import Foundation
import Combine

final class LocationService: NSObject, ObservableObject {

    private let locationManager = CLLocationManager()

    @Published private(set) var location: CLLocation?

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }


    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
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
