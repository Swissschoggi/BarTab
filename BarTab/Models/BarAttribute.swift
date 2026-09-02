import Foundation

// MARK: - Bar Attribute Keys

enum BarAttributeKey: String, CaseIterable, Identifiable {
    case outdoorSeating = "outdoor_seating"
    case smoking = "smoking"
    case dogsAllowed = "dogs_allowed"
    case wifi = "wifi"
    case cardAccepted = "card_accepted"
    case accessibility = "accessibility"
    case toilets = "toilets"
    case music = "music"
    case liveMusic = "live_music"
    case poolTable = "pool_table"
    case darts = "darts"
    case tableFootball = "table_football"
    case tvSports = "tv_sports"
    case food = "food"
    case outdoorSmoking = "outdoor_smoking"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .outdoorSeating: return "Outdoor Seating"
        case .smoking: return "Smoking"
        case .dogsAllowed: return "Dogs Allowed"
        case .wifi: return "Wi-Fi"
        case .cardAccepted: return "Card Payments"
        case .accessibility: return "Wheelchair Accessible"
        case .toilets: return "Toilets"
        case .music: return "Music"
        case .liveMusic: return "Live Music"
        case .poolTable: return "Pool Table"
        case .darts: return "Darts"
        case .tableFootball: return "Table Football"
        case .tvSports: return "TV Sports"
        case .food: return "Food Served"
        case .outdoorSmoking: return "Outdoor Smoking Area"
        }
    }

    var icon: String {
        switch self {
        case .outdoorSeating: return "sun.max.fill"
        case .smoking: return "smoke.fill"
        case .dogsAllowed: return "pawprint.fill"
        case .wifi: return "wifi"
        case .cardAccepted: return "creditcard.fill"
        case .accessibility: return "figure.roll"
        case .toilets: return "toilet.fill"
        case .music: return "music.note"
        case .liveMusic: return "music.mic"
        case .poolTable: return "circle.hexagongrid.fill"
        case .darts: return "target"
        case .tableFootball: return "figure.soccer"
        case .tvSports: return "tv.fill"
        case .food: return "fork.knife"
        case .outdoorSmoking: return "sun.max.fill"
        }
    }

    var possibleValues: [String] {
        switch self {
        case .outdoorSeating: return ["yes", "no"]
        case .smoking: return ["allowed", "not_allowed"]
        case .dogsAllowed: return ["yes", "no"]
        case .wifi: return ["yes", "no"]
        case .cardAccepted: return ["yes", "no"]
        case .accessibility: return ["yes", "no"]
        case .toilets: return ["yes", "no"]
        case .music: return ["yes", "no"]
        case .liveMusic: return ["yes", "no"]
        case .poolTable: return ["yes", "no"]
        case .darts: return ["yes", "no"]
        case .tableFootball: return ["yes", "no"]
        case .tvSports: return ["yes", "no"]
        case .food: return ["yes", "no"]
        case .outdoorSmoking: return ["yes", "no"]
        }
    }

    func displayValue(_ value: String) -> String {
        switch (self, value) {
        case (.smoking, "allowed"): return "Allowed"
        case (.smoking, "not_allowed"): return "Not Allowed"
        case (_, "yes"): return "Yes"
        case (_, "no"): return "No"
        default: return value.capitalized
        }
    }

    var isBoolean: Bool {
        possibleValues == ["yes", "no"] || possibleValues == ["allowed", "not_allowed"]
    }
}

// MARK: - Bar Attribute Report (user submission)

struct BarAttributeReport: Identifiable, Hashable {
    let id: UUID
    let barID: UUID
    let userID: UUID
    let attributeKey: String
    let attributeValue: String
    let evidenceText: String?
    let evidencePhotoURL: URL?
    let createdAt: Date
    let updatedAt: Date

    var attribute: BarAttributeKey? {
        BarAttributeKey(rawValue: attributeKey)
    }
}

// MARK: - Attribute Consensus (computed from reports)

struct AttributeConsensus: Identifiable, Hashable {
    let value: String
    let reportCount: Int
    let confidencePct: Int
    let lastConfirmedAt: Date

    var id: String { value }

    var displayValue: String {
        BarAttributeKey(rawValue: "")?.displayValue(value) ?? value.capitalized
    }
}

// MARK: - Bar Attribute (display model combining consensus + user's report)

struct BarAttribute: Identifiable {
    let key: BarAttributeKey
    let consensus: [AttributeConsensus]
    let myReport: BarAttributeReport?

    var id: String { key.rawValue }

    var topConsensus: AttributeConsensus? {
        consensus.first
    }

    var consensusValue: String? {
        topConsensus?.displayValue
    }

    var consensusConfidence: Int {
        topConsensus?.confidencePct ?? 0
    }

    var totalReports: Int {
        consensus.reduce(0) { $0 + $1.reportCount }
    }

    var myValue: String? {
        myReport?.attributeValue
    }

    var hasMyReport: Bool {
        myReport != nil
    }

    var isConfirmed: Bool {
        hasMyReport && myValue == topConsensus?.value
    }

    var lastConfirmedAt: Date? {
        topConsensus?.lastConfirmedAt
    }
}