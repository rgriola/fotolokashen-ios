import Foundation

/// User model matching backend API response from /api/v1/users/me
struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
    let avatar: String?
    let bannerImage: String?
    let bio: String?
    let city: String?
    let country: String?
    let emailVerified: Bool?
    let isActive: Bool?
    let isAdmin: Bool?
    let role: String?
    let createdAt: String?
    let updatedAt: String?

    // Preferences
    let language: String?
    let timezone: String?
    let emailNotifications: Bool?
    let gpsPermission: String?
    let gpsPermissionUpdated: String?

    // Home location
    let homeLocationName: String?
    let homeLocationLat: Double?
    let homeLocationLng: Double?
    let homeLocationUpdated: String?

    // Privacy settings
    let profileVisibility: String?
    let showInSearch: Bool?
    let showLocation: Bool?
    let showSavedLocations: String?
    let allowFollowRequests: Bool?

    // Onboarding (read-only on iOS)
    let onboardingCompleted: Bool?
    let termsAcceptedAt: String?
    let termsVersion: String?

    // MARK: - Computed Properties

    /// Full name (first + last)
    var fullName: String? {
        guard let first = firstName, let last = lastName else {
            return firstName ?? lastName
        }
        return "\(first) \(last)"
    }

    /// Display name (full name or username)
    var displayName: String {
        fullName ?? username
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

    /// Home location coordinates
    var homeLocation: (lat: Double, lng: Double)? {
        guard let lat = homeLocationLat, let lng = homeLocationLng else {
            return nil
        }
        return (lat, lng)
    }

    /// User initials for avatar placeholder
    var initials: String {
        let first = firstName?.prefix(1) ?? ""
        let last = lastName?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? String(username.prefix(1)).uppercased() : result
    }
}

// MARK: - Equatable

extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension User: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Profile Update Request

/// Request body for PATCH /api/v1/users/me
struct ProfileUpdateRequest: Codable {
    var firstName: String?
    var lastName: String?
    var bio: String?
    var city: String?
    var country: String?
    var language: String?
    var timezone: String?
    var emailNotifications: Bool?

    /// Returns true if all fields are nil (nothing to update)
    var isEmpty: Bool {
        firstName == nil && lastName == nil && bio == nil &&
        city == nil && country == nil && language == nil &&
        timezone == nil && emailNotifications == nil
    }
}

// MARK: - Privacy Update Request

/// Request body for PATCH /api/v1/users/me (privacy fields)
struct PrivacyUpdateRequest: Codable {
    var profileVisibility: String?
    var showInSearch: Bool?
    var showLocation: Bool?
    var showSavedLocations: String?
    var allowFollowRequests: Bool?
}

// MARK: - Avatar/Banner Response

/// Response from POST /api/auth/avatar or /api/auth/banner
struct ImageUploadResponse: Codable {
    let success: Bool
    let message: String?
    let avatarUrl: String?
    let bannerUrl: String?
}

// MARK: - V1 Me Response

/// Response from GET /api/v1/users/me
struct V1MeResponse: Codable {
    let user: User
}
