import Foundation

/// A group of locations representing a single event or activity
/// spanning multiple GPS coordinates (e.g., parade route, road trip, story coverage).
///
/// Maps to the `location_groups` table in the backend.
struct LocationGroup: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let type: String?         // preset (EVENT, ROUTE, STORY, COVERAGE) or custom
    let startTime: String?
    let endTime: String?
    let coverPhotoId: Int?
    let createdBy: Int
    let createdAt: String
    let updatedAt: String?

    /// Child locations (included when fetching group detail)
    let locations: [Location]?

    /// Location count (included in list responses)
    var locationCount: Int?
}

// MARK: - Equatable & Hashable

extension LocationGroup: Equatable {
    static func == (lhs: LocationGroup, rhs: LocationGroup) -> Bool {
        lhs.id == rhs.id
    }
}

extension LocationGroup: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preset Group Types

enum GroupTypePreset: String, CaseIterable {
    case event = "EVENT"
    case route = "ROUTE"
    case story = "STORY"
    case coverage = "COVERAGE"

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .event: return "calendar"
        case .route: return "map"
        case .story: return "book"
        case .coverage: return "video"
        }
    }
}

// MARK: - API Response Models

/// Response from GET /api/location-groups
struct LocationGroupsResponse: Codable {
    let groups: [LocationGroup]
}

/// Response from POST /api/location-groups
struct CreateLocationGroupResponse: Codable {
    let group: LocationGroup
}

/// Response from GET /api/user-group-types
struct GroupTypesResponse: Codable {
    let presets: [String]
    let customTypes: [CustomGroupType]
}

/// A user's custom group type
struct CustomGroupType: Codable, Identifiable {
    let id: Int
    let typeName: String
    let createdAt: String
}

/// Response from POST /api/user-group-types
struct CreateCustomTypeResponse: Codable {
    let customType: CustomGroupType
}
