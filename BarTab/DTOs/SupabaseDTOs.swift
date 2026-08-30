import Foundation
import CoreLocation

// MARK: - Nested bar ref (for activity feed)

struct BarNameRef: Codable {
    let name: String
}

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
    let outdoor_seating: Bool

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
            smokingFriendly: smoking_friendly,
            outdoorSeating: outdoor_seating
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
        self.outdoor_seating = domain.outdoorSeating
    }
}

/// Minimal DTO for PATCH — only mutable fields, avoids sending
/// immutable columns that PostgREST may reject.
struct BarPatchDTO: Codable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let smoking_friendly: Bool
    let outdoor_seating: Bool

    init(from bar: Bar) {
        self.name = bar.name
        self.address = bar.address
        self.latitude = bar.coordinate.latitude
        self.longitude = bar.coordinate.longitude
        self.smoking_friendly = bar.smokingFriendly
        self.outdoor_seating = bar.outdoorSeating
    }
}

// MARK: - Bar Rating DTO

struct BarRatingDTO: Codable {
    let id: UUID
    let bar_id: UUID
    let rated_by: UUID
    let ambience: String?
    let wine_quality: Int?
    let created_at: Date
    let bars: BarNameRef?

    var toDomain: BarRating {
        let styles: [AmbienceStyle] = {
            guard let ambience else { return [] }
            return ambience.split(separator: ",")
                .compactMap { AmbienceStyle(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
        }()
        return BarRating(
            id: id,
            barID: bar_id,
            ratedBy: rated_by,
            ambience: styles,
            wineQuality: wine_quality,
            createdAt: created_at
        )
    }

    init(from domain: BarRating) {
        self.id = domain.id
        self.bar_id = domain.barID
        self.rated_by = domain.ratedBy
        self.ambience = domain.ambience.isEmpty ? nil : domain.ambience.map(\.rawValue).joined(separator: ",")
        self.wine_quality = domain.wineQuality
        self.created_at = domain.createdAt
        self.bars = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bar_id, forKey: .bar_id)
        try container.encode(rated_by, forKey: .rated_by)
        // Always encode both dimensions so an upsert never
        // overwrites the other dimension with NULL.
        if let ambience {
            try container.encode(ambience, forKey: .ambience)
        } else {
            try container.encodeNil(forKey: .ambience)
        }
        try container.encodeIfPresent(wine_quality, forKey: .wine_quality)
        try container.encode(created_at, forKey: .created_at)
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
    let style: String?
    let serving: String?
    let bars: BarNameRef?

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
            reportedBy: reported_by,
            style: style,
            serving: serving.flatMap { ServingMethod(rawValue: $0) }
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
        self.style = domain.style
        self.serving = domain.serving?.rawValue
        self.bars = nil
    }

    /// Custom decoder that handles missing style/serving fields
    /// gracefully for backward compatibility with existing Supabase data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bar_id = try container.decode(UUID.self, forKey: .bar_id)
        drink = try container.decode(String.self, forKey: .drink)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        size = try container.decode(String.self, forKey: .size)
        amount = try container.decode(Decimal.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        reported_at = try container.decode(Date.self, forKey: .reported_at)
        reported_by = try container.decode(UUID.self, forKey: .reported_by)
        style = try container.decodeIfPresent(String.self, forKey: .style)
        serving = try container.decodeIfPresent(String.self, forKey: .serving)
        bars = try container.decodeIfPresent(BarNameRef.self, forKey: .bars)
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

// MARK: - Drink Rating DTO

struct DrinkRatingDTO: Codable {
    let id: UUID
    let bar_id: UUID
    let drink: String
    let brand: String?
    let size: String
    let quality: Int
    let rated_by: UUID
    let created_at: Date
    let bars: BarNameRef?

    var toDomain: DrinkRating? {
        guard let drinkEnum = Drink(rawValue: drink),
              let sizeEnum = DrinkSize(rawValue: size) else {
            return nil
        }

        return DrinkRating(
            id: id,
            barID: bar_id,
            drink: drinkEnum,
            brand: brand,
            size: sizeEnum,
            quality: quality,
            ratedBy: rated_by,
            createdAt: created_at
        )
    }

    init(from domain: DrinkRating) {
        self.id = domain.id
        self.bar_id = domain.barID
        self.drink = domain.drink.rawValue
        self.brand = domain.brand
        self.size = domain.size.rawValue
        self.quality = domain.quality
        self.rated_by = domain.ratedBy
        self.created_at = domain.createdAt
    }
}

// MARK: - Content Report DTO

struct ContentReportDTO: Codable {
    let id: UUID
    let target_id: String
    let target_type: String
    let target_label: String
    let reason: String
    let reported_by: UUID
    let reported_by_name: String
    let reported_at: Date
    let is_reviewed: Bool
    let reviewed_at: Date?

    var toDomain: ContentReport? {
        guard let type = reportTargetType(from: target_type),
              let reason = ReportReason(rawValue: reason) else {
            return nil
        }

        return ContentReport(
            id: id,
            targetID: target_id,
            targetType: type,
            targetLabel: target_label,
            reason: reason,
            reportedBy: reported_by,
            reportedByName: reported_by_name,
            reportedAt: reported_at,
            isReviewed: is_reviewed,
            reviewedAt: reviewed_at
        )
    }

    init(from domain: ContentReport) {
        self.id = domain.id
        self.target_id = domain.targetID
        switch domain.targetType {
        case .bar:
            self.target_type = "bar"
        case .price:
            self.target_type = "price"
        }
        self.target_label = domain.targetLabel
        self.reason = domain.reason.rawValue
        self.reported_by = domain.reportedBy
        self.reported_by_name = domain.reportedByName
        self.reported_at = domain.reportedAt
        self.is_reviewed = domain.isReviewed
        self.reviewed_at = domain.reviewedAt
    }

    private func reportTargetType(
        from rawValue: String
    ) -> ReportTargetType? {
        switch rawValue {
        case "bar":
            return .bar
        case "price":
            return .price
        default:
            return nil
        }
    }
}

// MARK: - Profile DTO

struct ProfileDTO: Codable, Identifiable {
    let id: UUID
    let display_name: String?
    let is_admin: Bool
    let avatar_url: String?
}
