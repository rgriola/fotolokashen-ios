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
    let createdAt: String
    let photosCount: Int
    
    /// Coordinate for use with MapKit/Google Maps
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    /// Location type enum
    var locationType: LocationType {
        LocationType(rawValue: type ?? "") ?? .unknown
    }
    
    /// Has photos
    var hasPhotos: Bool {
        photosCount > 0
    }
    
    /// Created date
    var createdDate: Date? {
        ISO8601DateFormatter().date(from: createdAt)
    }
}

// MARK: - Location Type

enum LocationType: String, Codable, CaseIterable {
    case outdoor = "outdoor"
    case indoor = "indoor"
    case studio = "studio"
    case urban = "urban"
    case nature = "nature"
    case architectural = "architectural"
    case unknown = ""
    
    var displayName: String {
        switch self {
        case .outdoor: return "Outdoor"
        case .indoor: return "Indoor"
        case .studio: return "Studio"
        case .urban: return "Urban"
        case .nature: return "Nature"
        case .architectural: return "Architectural"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .outdoor: return "sun.max"
        case .indoor: return "house"
        case .studio: return "camera.fill"
        case .urban: return "building.2"
        case .nature: return "leaf"
        case .architectural: return "building.columns"
        case .unknown: return "mappin"
        }
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
    let address: String?
    let lat: Double
    let lng: Double
    let type: String?
    let notes: String?
    let rating: Double?
}

// MARK: - Update Location Request

struct UpdateLocationRequest: Codable {
    let name: String?
    let notes: String?
    let rating: Double?
    let type: String?
}

// MARK: - Example JSON Response
/*
 {
   "id": 456,
   "placeId": "photo-1234567890",
   "name": "Beautiful Sunset Spot",
   "address": "123 Main St, City, State",
   "lat": 37.7749,
   "lng": -122.4194,
   "type": "outdoor",
   "notes": "Great for golden hour",
   "rating": 4.5,
   "createdAt": "2026-01-12T10:30:00Z",
   "photosCount": 5
 }
 */
