import Foundation
import SwiftData

/// SwiftData model for locally cached locations
@available(iOS 17, *)
@Model
final class CachedLocation {
    @Attribute(.unique) var id: Int
    var placeId: String
    var name: String
    var address: String?
    var lat: Double
    var lng: Double
    var type: String?
    var notes: String?
    var rating: Double?
    var createdAt: String
    var lastSyncedAt: Date
    var isSynced: Bool
    
    // Relationships
    @Relationship(deleteRule: .cascade) var photos: [CachedPhoto]?
    
    init(
        id: Int,
        placeId: String,
        name: String,
        address: String?,
        lat: Double,
        lng: Double,
        type: String?,
        notes: String? = nil,
        rating: Double? = nil,
        createdAt: String,
        lastSyncedAt: Date = Date(),
        isSynced: Bool = true
    ) {
        self.id = id
        self.placeId = placeId
        self.name = name
        self.address = address
        self.lat = lat
        self.lng = lng
        self.type = type
        self.notes = notes
        self.rating = rating
        self.createdAt = createdAt
        self.lastSyncedAt = lastSyncedAt
        self.isSynced = isSynced
    }
    
    /// Convert to API Location model
    func toLocation() -> Location {
        return Location(
            id: id,
            name: name,
            address: address ?? "",
            latitude: lat,
            longitude: lng,
            type: type ?? "",
            placeId: placeId,
            createdAt: createdAt,
            photosCount: photos?.count,
            thumbnailUrl: nil
        )
    }
    
    /// Create from API Location model
    static func from(_ location: Location) -> CachedLocation {
        return CachedLocation(
            id: location.id,
            placeId: location.placeId,
            name: location.name,
            address: location.address,
            lat: location.lat,
            lng: location.lng,
            type: location.type,
            notes: location.notes,
            rating: location.rating,
            createdAt: location.createdAt,
            lastSyncedAt: Date(),
            isSynced: true
        )
    }
}
