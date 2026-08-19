import Foundation
import CoreLocation

extension Bar {

    static let mockBars: [Bar] = [

        Bar(
            id: UUID(),
            name: "Test Bar Zürich",
            address: "Langstrasse 1, Zürich",
            coordinate: CLLocationCoordinate2D(
                latitude: 47.3779,
                longitude: 8.5332
            ),
            createdAt: Date(),
            createdBy: User.mockUser.id
        ),

        Bar(
            id: UUID(),
            name: "Another Bar",
            address: "Niederdorf 10, Zürich",
            coordinate: CLLocationCoordinate2D(
                latitude: 47.3745,
                longitude: 8.5430
            ),
            createdAt: Date(),
            createdBy: User.mockUser.id
        )
    ]
}
