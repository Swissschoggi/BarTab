import Foundation
import CoreLocation

struct Bar: Identifiable {

    let id: UUID

    let name: String
    let address: String

    let coordinate: CLLocationCoordinate2D

    let createdAt: Date
    let createdBy: UUID

    /// Whether smoking (or a smoking area) is allowed at this bar.
    let smokingFriendly: Bool

    init(
        id: UUID,
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        createdAt: Date,
        createdBy: UUID,
        smokingFriendly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.smokingFriendly = smokingFriendly
    }
}
