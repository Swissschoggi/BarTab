import CoreLocation

@MainActor
final class LocationServices: NSObject, ObservableObject {

    private let locationManager = CLLocationManager()

    override init() {
        super.init()

        locationManager.delegate = self
    }
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }    
}

extension LocationService: CLLocationManagerDelegate {
}