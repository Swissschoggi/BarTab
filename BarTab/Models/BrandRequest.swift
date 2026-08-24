import Foundation

enum BrandRequestStatus: String, Codable {
    case pending
    case approved
    case rejected
}

/// A user's request to add a brand that isn't in the catalog yet.
/// Reviewed by an admin, who can approve it (adding it to the
/// shared brand catalog) or reject it.
struct BrandRequest: Identifiable {

    let id: UUID
    let drink: Drink
    let name: String
    let requestedBy: UUID
    let requestedByName: String
    var status: BrandRequestStatus
    let createdAt: Date
}
