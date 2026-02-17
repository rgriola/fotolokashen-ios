import Foundation
import CoreLocation

/// Location model matching backend API response
struct Location: Codable, Identifiable {
    let id: Int
    let placeId: String
    let name: String
    let address: String?
    let lat: Double
    let lng: Double
    let type: String?
    let notes: String?
    let rating: Double?
    let productionDate: Date?  // Production/filming date (optional)
    let createdAt: String
    let photos: [LocationPhoto]?

    // MARK: - Production Detail Fields

    let productionNotes: String?
    let entryPoint: String?
    let parking: String?
    let access: String?
    let indoorOutdoor: String?
    let isPermanent: Bool?

    // MARK: - Address Components

    let street: String?
    let number: String?
    let city: String?
    let state: String?
    let zipcode: String?

    // MARK: - Mutable / UserSave Fields

    /// UserSave ID - used for delete/update operations (different from location id)
    var userSaveId: Int?
    /// User's custom color for this location
    var color: String?
    /// Whether the user has favorited this location
    var isFavorite: Bool?
    /// User's personal rating (separate from shared rating)
    var personalRating: Double?
    /// User's personal caption
    var caption: String?
    /// User's tags for this location
    var tags: [String]?
    /// User's visibility setting for this save
    var visibility: String?

    /// Convenience initializer for creating locations with latitude/longitude
    init(
        id: Int,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        type: String,
        placeId: String,
        createdAt: String,
        photosCount: Int?,
        thumbnailUrl: String?,
        userSaveId: Int? = nil,
        productionDate: Date? = nil,
        productionNotes: String? = nil,
        entryPoint: String? = nil,
        parking: String? = nil,
        access: String? = nil,
        indoorOutdoor: String? = nil,
        isPermanent: Bool? = nil,
        street: String? = nil,
        number: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zipcode: String? = nil,
        color: String? = nil,
        isFavorite: Bool? = nil,
        personalRating: Double? = nil,
        caption: String? = nil,
        tags: [String]? = nil,
        visibility: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.lat = latitude
        self.lng = longitude
        self.type = type
        self.placeId = placeId
        self.createdAt = createdAt
        self.photos = nil
        self.notes = nil
        self.rating = nil
        self.productionDate = productionDate
        self.userSaveId = userSaveId
        self.productionNotes = productionNotes
        self.entryPoint = entryPoint
        self.parking = parking
        self.access = access
        self.indoorOutdoor = indoorOutdoor
        self.isPermanent = isPermanent
        self.street = street
        self.number = number
        self.city = city
        self.state = state
        self.zipcode = zipcode
        self.color = color
        self.isFavorite = isFavorite
        self.personalRating = personalRating
        self.caption = caption
        self.tags = tags
        self.visibility = visibility
    }

    /// Latitude (convenience property)
    var latitude: Double { lat }

    /// Longitude (convenience property)
    var longitude: Double { lng }

    /// Photo count (computed from photos array)
    var photosCount: Int? {
        photos?.count
    }

    /// Thumbnail URL (computed from first photo)
    var thumbnailUrl: String? {
        guard let firstPhoto = photos?.first else { return nil }
        // Construct ImageKit URL from file path
        return "https://ik.imagekit.io/rgriola\(firstPhoto.imagekitFilePath)"
    }

    /// Coordinate for use with MapKit/Google Maps
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Location type display name
    var locationType: LocationType {
        LocationType(rawValue: type?.uppercased() ?? "") ?? .other
    }

    /// Has photos
    var hasPhotos: Bool {
        (photosCount ?? 0) > 0
    }

    /// Created date
    var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
}

// MARK: - Location Photo

/// Simplified photo model for location list
struct LocationPhoto: Codable {
    let id: Int
    let imagekitFilePath: String
    let isPrimary: Bool?
}

// MARK: - API Response Models

/// Response for fetching a single location (by UserSave ID)
struct UserSaveDetailResponse: Codable {
    let userSave: UserSaveWithLocation
}

/// UserSave with full location details including photos
struct UserSaveWithLocation: Codable {
    let id: Int
    let userId: Int
    let locationId: Int
    let location: Location
    let savedAt: String?
    let color: String?
    let isFavorite: Bool?
    let personalRating: Double?
    let caption: String?
    let tags: [String]?
    let visibility: String?
}

/// Response for fetching multiple locations
struct LocationsResponse: Codable {
    let locations: [UserSaveWrapper]

    /// Unwrap the locations from UserSave objects, preserving userSaveId and UserSave fields
    var unwrappedLocations: [Location] {
        locations.map { wrapper in
            var location = wrapper.location
            location.userSaveId = wrapper.id  // Preserve the UserSave ID for delete/update operations
            location.color = wrapper.color
            location.isFavorite = wrapper.isFavorite
            location.personalRating = wrapper.personalRating
            location.caption = wrapper.caption
            location.tags = wrapper.tags
            location.visibility = wrapper.visibility
            return location
        }
    }
}

/// Wrapper for UserSave objects returned by GET /api/locations
struct UserSaveWrapper: Codable {
    let id: Int
    let userId: Int
    let locationId: Int
    let location: Location
    let savedAt: String?
    let color: String?
    let isFavorite: Bool?
    let personalRating: Double?
    let caption: String?
    let tags: [String]?
    let visibility: String?
}

/// Empty response for delete operations
struct EmptyResponse: Codable {
    // Empty struct for endpoints that return no data
}

// MARK: - Location Type

/// Location types matching the web app's 15 types (LocationTypeColors is source of truth for colors/icons)
enum LocationType: String, Codable, CaseIterable {
    case broll = "BROLL"
    case story = "STORY"
    case interview = "INTERVIEW"
    case liveAnchor = "LIVE ANCHOR"
    case reporterLive = "REPORTER LIVE"
    case stakeout = "STAKEOUT"
    case drone = "DRONE"
    case scene = "SCENE"
    case event = "EVENT"
    case bathroom = "BATHROOM"
    case other = "OTHER"
    // Admin-only types
    case hq = "HQ"
    case bureau = "BUREAU"
    case remoteStaff = "REMOTE STAFF"
    case storage = "STORAGE"

    var displayName: String {
        rawValue
    }

    var icon: String {
        LocationTypeColors.icon(for: rawValue)
    }

    /// Standard (non-admin) types
    static var standardTypes: [LocationType] {
        [.broll, .story, .interview, .liveAnchor, .reporterLive, .stakeout,
         .drone, .scene, .event, .bathroom, .other]
    }

    /// Admin-only types
    static var adminTypes: [LocationType] {
        [.hq, .bureau, .remoteStaff, .storage]
    }
}

// MARK: - Equatable

extension Location: Equatable {
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension Location: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Create Location Request

struct CreateLocationRequest: Codable {
    let placeId: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let type: String?
    let notes: String?
    let rating: Double?
    let productionDate: String?  // ISO date string (YYYY-MM-DD)
    // Address components for database
    let street: String?
    let city: String?
    let state: String?
    let zipcode: String?
}

// MARK: - Create Location Response

struct CreateLocationResponse: Codable {
    let userSave: UserSaveResponse
}

struct UserSaveResponse: Codable {
    let id: Int
    let userId: Int
    let locationId: Int
    let location: Location
}

// MARK: - Update Location Request

/// Request body for PATCH /api/locations/{id}
/// Combines Location fields AND UserSave fields in a single request
struct UpdateLocationRequest: Codable {
    // Location fields (shared)
    var name: String?
    var notes: String?
    var rating: Double?
    var type: String?
    var productionDate: String?  // ISO date string (YYYY-MM-DD), null to remove
    var productionNotes: String?
    var entryPoint: String?
    var parking: String?
    var access: String?
    var indoorOutdoor: String?
    var isPermanent: Bool?
    // Address components
    var street: String?
    var number: String?
    var city: String?
    var state: String?
    var zipcode: String?
    // UserSave fields (per-user)
    var tags: [String]?
    var isFavorite: Bool?
    var personalRating: Double?
    var color: String?
}

// MARK: - Update Location Response

/// Response from PATCH /api/locations/{id}
/// The backend returns { data: { location: {..., photos}, userSave: {...} } }
struct UpdateLocationResponse: Codable {
    let location: Location
    let userSave: UpdatedUserSave?
}

/// UserSave portion of the PATCH response
struct UpdatedUserSave: Codable {
    let id: Int
    let userId: Int
    let locationId: Int
    let tags: [String]?
    let isFavorite: Bool?
    let personalRating: Double?
    let color: String?
    let savedAt: String?
    let caption: String?
    let visibility: String?
}

// MARK: - Example JSON Response
/*
 PATCH /api/locations/{id} response:
 {
   "data": {
     "location": {
       "id": 456,
       "placeId": "photo-1234567890",
       "name": "Beautiful Sunset Spot",
       "address": "123 Main St, City, State",
       "lat": 37.7749,
       "lng": -122.4194,
       "type": "BROLL",
       "notes": "Great for golden hour",
       "rating": 4.5,
       "productionNotes": "Need permit for tripod",
       "entryPoint": "Side entrance",
       "parking": "Street parking available",
       "access": "Public",
       "indoorOutdoor": "outdoor",
       "isPermanent": true,
       "photos": [...]
     },
     "userSave": {
       "id": 789,
       "userId": 1,
       "locationId": 456,
       "tags": ["sunset", "golden-hour"],
       "isFavorite": true,
       "personalRating": 5.0,
       "color": "#FF5733"
     }
   }
 }
 */
