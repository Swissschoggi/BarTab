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
    let smoking_friendly: Bool

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
            createdBy: created_by,
            smokingFriendly: smoking_friendly
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
        self.smoking_friendly = domain.smokingFriendly
    }
}

// MARK: - Bar Rating DTO

struct BarRatingDTO: Codable {
    let id: UUID
    let bar_id: UUID
    let rated_by: UUID
    let ambience: Int?
    let wine_quality: Int?
    let created_at: Date

    var toDomain: BarRating {
        BarRating(
            id: id,
            barID: bar_id,
            ratedBy: rated_by,
            ambience: ambience,
            wineQuality: wine_quality,
            createdAt: created_at
        )
    }

    init(from domain: BarRating) {
        self.id = domain.id
        self.bar_id = domain.barID
        self.rated_by = domain.ratedBy
        self.ambience = domain.ambience
        self.wine_quality = domain.wineQuality
        self.created_at = domain.createdAt
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

// MARK: - Drink Brand DTO

struct DrinkBrandDTO: Codable {
    let id: UUID
    let drink: String
    let name: String
    let created_at: Date

    var toDomain: DrinkBrand {
        DrinkBrand(
            id: id.uuidString,
            name: name,
            drink: Drink(rawValue: drink) ?? .other
        )
    }
}

// MARK: - Brand Request DTO

struct BrandRequestDTO: Codable {
    let id: UUID
    let drink: String
    let name: String
    let requested_by: UUID
    let requested_by_name: String
    let status: String
    let created_at: Date

    var toDomain: BrandRequest {
        BrandRequest(
            id: id,
            drink: Drink(rawValue: drink) ?? .other,
            name: name,
            requestedBy: requested_by,
            requestedByName: requested_by_name,
            status: BrandRequestStatus(rawValue: status) ?? .pending,
            createdAt: created_at
        )
    }

    init(from domain: BrandRequest) {
        self.id = domain.id
        self.drink = domain.drink.rawValue
        self.name = domain.name
        self.requested_by = domain.requestedBy
        self.requested_by_name = domain.requestedByName
        self.status = domain.status.rawValue
        self.created_at = domain.createdAt
    }
}
