import Foundation

// MARK: - Public Profile

/// Public user profile from GET /api/v1/users/{username}
struct PublicUser: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let username: String
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let avatar: String?
    let bannerImage: String?
    let bio: String?
    let publicLocationCount: Int?
    let joinedAt: String?
    let profileUrl: String?

    // MARK: - Computed Properties

    /// Display name (falls back to username)
    var name: String {
        displayName ?? username
    }

    /// Avatar URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: avatar)
    }

    /// Banner image URL
    var bannerURL: URL? {
        guard let banner = bannerImage else { return nil }
        return URL(string: banner)
    }

    /// User initials for avatar placeholder
    var initials: String {
        let first = firstName?.prefix(1) ?? ""
        let last = lastName?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? String(username.prefix(1)).uppercased() : result
    }

    // MARK: - Equatable / Hashable

    static func == (lhs: PublicUser, rhs: PublicUser) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Follow Status

/// Response from GET /api/v1/users/me/follow-status/{username}
struct FollowStatus: Codable {
    let isFollowing: Bool
    let isFollowedBy: Bool
    let followedAt: String?
}

// MARK: - Follow Response

/// Response from POST /api/v1/users/{username}/follow
struct FollowResponse: Codable {
    let success: Bool
    let follower: FollowUser?
    let following: FollowUser?
    let followedAt: String?
}

/// Minimal user info in follow response
struct FollowUser: Codable {
    let id: Int
    let username: String
}

// MARK: - Unfollow Response

/// Response from POST /api/v1/users/{username}/unfollow
struct UnfollowResponse: Codable {
    let success: Bool
    let message: String?
}

// MARK: - Followers / Following List

/// A user in a followers/following list
struct FollowListUser: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let username: String
    let displayName: String?
    let avatar: String?
    let bio: String?
    let followedAt: String?

    /// Display name (falls back to username)
    var name: String {
        displayName ?? username
    }

    /// Avatar URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: avatar)
    }

    /// User initials for avatar placeholder
    var initials: String {
        String(username.prefix(1)).uppercased()
    }

    static func == (lhs: FollowListUser, rhs: FollowListUser) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Pagination metadata
struct PaginationInfo: Codable {
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
    let hasMore: Bool
}

/// Response from GET /api/v1/users/{username}/followers
struct FollowersResponse: Codable {
    let followers: [FollowListUser]
    let pagination: PaginationInfo
}

/// Response from GET /api/v1/users/{username}/following
struct FollowingResponse: Codable {
    let following: [FollowListUser]
    let pagination: PaginationInfo
}

// MARK: - People Search

/// Response from GET /api/v1/search/users
struct UserSearchResponse: Codable {
    let users: [SearchUser]
    let total: Int?
    let query: String?
}

/// A user in search results
struct SearchUser: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let username: String
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let avatar: String?
    let bio: String?
    let city: String?
    let country: String?

    /// Display name (falls back to username)
    var name: String {
        displayName ?? username
    }

    /// Avatar URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: avatar)
    }

    /// User initials for avatar placeholder
    var initials: String {
        let first = firstName?.prefix(1) ?? ""
        let last = lastName?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? String(username.prefix(1)).uppercased() : result
    }

    /// Location string (city, country)
    var locationString: String? {
        [city, country].compactMap { $0 }.joined(separator: ", ")
    }

    static func == (lhs: SearchUser, rhs: SearchUser) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Response from GET /api/v1/search/suggestions
struct SearchSuggestionsResponse: Codable {
    let suggestions: [String]
    let query: String?
}

// MARK: - Social Locations

/// A location saved by another user (from public/friends endpoints)
struct SocialLocation: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let caption: String?
    let savedAt: String?
    let location: SocialLocationDetail

    static func == (lhs: SocialLocation, rhs: SocialLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Location detail within a social location response
/// Supports both lat/lng (canonical) and latitude/longitude (legacy) field names
struct SocialLocationDetail: Equatable, Hashable {
    let id: Int
    let placeId: String?
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let lat: Double
    let lng: Double
    let type: String?
    let rating: Double?
    let photos: [LocationPhoto]?

    /// Coordinate for map display
    var latitude: Double { lat }
    var longitude: Double { lng }

    /// Location type
    var locationType: LocationType {
        LocationType(rawValue: type?.uppercased() ?? "") ?? .other
    }

    /// Thumbnail URL from first photo (optimized for list display)
    var thumbnailUrl: String? {
        guard let firstPhoto = photos?.first else { return nil }
        return ImageKitURL.url(for: firstPhoto.imagekitFilePath, variant: .thumbnail)?.absoluteString
            ?? "\(ImageKitURL.baseURL)\(firstPhoto.imagekitFilePath)"
    }

    static func == (lhs: SocialLocationDetail, rhs: SocialLocationDetail) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - SocialLocationDetail Codable (handles lat/lng OR latitude/longitude)

extension SocialLocationDetail: Codable {
    enum CodingKeys: String, CodingKey {
        case id, placeId, name, address, city, state, type, rating, photos
        // Primary field names (canonical)
        case lat, lng
        // Fallback field names (legacy API)
        case latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        photos = try container.decodeIfPresent([LocationPhoto].self, forKey: .photos)

        // Try lat/lng first (canonical), then fall back to latitude/longitude (legacy)
        if let latValue = try container.decodeIfPresent(Double.self, forKey: .lat) {
            lat = latValue
        } else {
            lat = try container.decode(Double.self, forKey: .latitude)
        }

        if let lngValue = try container.decodeIfPresent(Double.self, forKey: .lng) {
            lng = lngValue
        } else {
            lng = try container.decode(Double.self, forKey: .longitude)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(placeId, forKey: .placeId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(photos, forKey: .photos)
        // Always encode as canonical lat/lng
        try container.encode(lat, forKey: .lat)
        try container.encode(lng, forKey: .lng)
    }
}

/// A public/friends location with user info (from /api/v1/locations/public or /friends)
struct MapSocialLocation: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let placeId: String?
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let lat: Double
    let lng: Double
    let type: String?
    let rating: Double?
    let caption: String?
    let savedAt: String?
    let user: SocialLocationUser?

    /// Coordinate for map display
    var latitude: Double { lat }
    var longitude: Double { lng }

    /// Location type
    var locationType: LocationType {
        LocationType(rawValue: type?.uppercased() ?? "") ?? .other
    }

    static func == (lhs: MapSocialLocation, rhs: MapSocialLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// User info attached to a social location on the map
struct SocialLocationUser: Codable, Equatable, Hashable {
    let id: Int
    let username: String
    let firstName: String?
    let lastName: String?
    let avatar: String?

    /// Display name
    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return firstName ?? lastName ?? username
    }

    /// Avatar URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: avatar)
    }
}

/// Response from GET /api/v1/users/{username}/locations
struct UserLocationsResponse: Codable {
    let locations: [SocialLocation]
    let pagination: PaginationInfo?
}

/// Response from GET /api/v1/locations/public or /friends
struct MapSocialLocationsResponse: Codable {
    let locations: [MapSocialLocation]
}
