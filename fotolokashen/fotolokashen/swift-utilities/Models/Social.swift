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
struct SocialLocationDetail: Codable, Equatable, Hashable {
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

    /// Thumbnail URL from first photo
    var thumbnailUrl: String? {
        guard let firstPhoto = photos?.first else { return nil }
        return "https://ik.imagekit.io/rgriola\(firstPhoto.imagekitFilePath)"
    }

    static func == (lhs: SocialLocationDetail, rhs: SocialLocationDetail) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
