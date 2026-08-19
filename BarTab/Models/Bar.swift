import Foundation
import CoreLocation

struct Bar: Identifiable {

    let id: UUID

    let name: String
    let address: String

    let coordinate: CLLocationCoordinate2D

    let createdAt: Date
    let createdBy: UUID
}
