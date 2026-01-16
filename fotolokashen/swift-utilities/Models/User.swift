import Foundation

/// User model matching backend API response
struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
    let avatar: String?
    let bannerImage: String?
    let city: String?
    let country: String?
    let emailVerified: Bool
    let isActive: Bool
    let isAdmin: Bool
    let createdAt: String
    
    // Optional fields
    let language: String?
    let timezone: String?
    let emailNotifications: Bool?
    let gpsPermission: String?
    let gpsPermissionUpdated: String?
    let homeLocationName: String?
    let homeLocationLat: Double?
    let homeLocationLng: Double?
    let homeLocationUpdated: String?
    
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

// MARK: - Example JSON Response
/*
 {
   "id": 123,
   "email": "user@example.com",
   "username": "johndoe",
   "firstName": "John",
   "lastName": "Doe",
   "avatar": "https://ik.imagekit.io/rgriola/users/123/avatar.jpg",
   "bannerImage": null,
   "city": "New York",
   "country": "USA",
   "emailVerified": true,
   "isActive": true,
   "isAdmin": false,
   "createdAt": "2026-01-15T10:30:00Z",
   "language": "en",
   "timezone": "America/New_York",
   "emailNotifications": true,
   "gpsPermission": "granted",
   "gpsPermissionUpdated": "2026-01-15T10:30:00Z",
   "homeLocationName": "Home",
   "homeLocationLat": 40.7128,
   "homeLocationLng": -74.0060,
   "homeLocationUpdated": "2026-01-15T10:30:00Z"
 }
 */
