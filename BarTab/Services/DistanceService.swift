import CoreLocation

struct DistanceService {

    static func distance(
        from location: CLLocation,
        to bar: Bar
    ) -> CLLocationDistance {

        let barLocation = CLLocation(
            latitude: bar.coordinate.latitude,
            longitude: bar.coordinate.longitude
        )

        return location.distance(from: barLocation)
    }

    static func formattedDistance(
        from location: CLLocation,
        to bar: Bar
    ) -> String {

        let distance = Self.distance(
            from: location,
            to: bar
        )

        if distance < 1000 {
            return "\(Int(distance)) m"
        }

        return String(
            format: "%.1f km",
            distance / 1000
        )
    }
}
