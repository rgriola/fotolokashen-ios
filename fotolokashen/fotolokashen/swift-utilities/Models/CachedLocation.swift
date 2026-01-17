import Foundation
import SwiftData

/// SwiftData model for locally cached locations
@Model
final class CachedLocation {
    @Attribute(.unique) var id: Int
    var name: String
    var locationTypeId: Int
    var latitude: Double
    var longitude: Double
    var formattedAddress: String?
    var userId: Int
    var createdAt: String
    var updatedAt: String?
    var lastSyncedAt: Date
    var isSynced: Bool
    
    // Relationships
    @Relationship(deleteRule: .cascade) var photos: [CachedPhoto]?
    
    init(
        id: Int,
        name: String,
        locationTypeId: Int,
        latitude: Double,
        longitude: Double,
        formattedAddress: String?,
        userId: Int,
        createdAt: String,
        updatedAt: String? = nil,
        lastSyncedAt: Date = Date(),
        isSynced: Bool = true
    ) {
        self.id = id
        self.name = name
        self.locationTypeId = locationTypeId
        self.latitude = latitude
        self.longitude = longitude
        self.formattedAddress = formattedAddress
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
        self.isSynced = isSynced
    }
    
    /// Convert to API Location model
    func toLocation() -> Location {
        return Location(
            id: id,
            name: name,
            locationTypeId: locationTypeId,
            latitude: latitude,
            longitude: longitude,
            formattedAddress: formattedAddress,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Create from API Location model
    static func from(_ location: Location) -> CachedLocation {
        return CachedLocation(
            id: location.id,
            name: location.name,
            locationTypeId: location.locationTypeId,
            latitude: location.latitude,
            longitude: location.longitude,
            formattedAddress: location.formattedAddress,
            userId: location.userId,
            createdAt: location.createdAt,
            updatedAt: location.updatedAt,
            lastSyncedAt: Date(),
            isSynced: true
        )
    }
}
