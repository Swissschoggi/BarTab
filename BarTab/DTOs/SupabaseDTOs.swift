import Foundation
import CoreLocation

// MARK: - Bar DTO

struct BarDTO: Codable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let created_at: Date
    let created_by: UUID

    var toDomain: Bar {
        Bar(
            id: id,
            name: name,
            address: address,
            coordinate: CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            ),
            createdAt: created_at,
            createdBy: created_by
        )
    }

    init(from domain: Bar) {
        self.id = domain.id
        self.name = domain.name
        self.address = domain.address
        self.latitude = domain.coordinate.latitude
        self.longitude = domain.coordinate.longitude
        self.created_at = domain.createdAt
        self.created_by = domain.createdBy
    }
}

// MARK: - Price DTO

struct PriceDTO: Codable {
    let id: UUID
    let bar_id: UUID
    let drink: String
    let brand: String?
    let size: String
    let amount: Decimal
    let currency: String
    let reported_at: Date
    let reported_by: UUID

    var toDomain: Price? {
        guard let drinkEnum = Drink(rawValue: drink),
              let sizeEnum = DrinkSize(rawValue: size) else {
            return nil
        }

        return Price(
            id: id,
            barID: bar_id,
            drink: drinkEnum,
            brand: brand,
            size: sizeEnum,
            amount: amount,
            currency: currency,
            reportedAt: reported_at,
            reportedBy: reported_by
        )
    }

    init(from domain: Price) {
        self.id = domain.id
        self.bar_id = domain.barID
        self.drink = domain.drink.rawValue
        self.brand = domain.brand
        self.size = domain.size.rawValue
        self.amount = domain.amount
        self.currency = domain.currency
        self.reported_at = domain.reportedAt
        self.reported_by = domain.reportedBy
    }
}
