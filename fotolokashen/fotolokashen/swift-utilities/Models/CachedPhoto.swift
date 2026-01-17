import Foundation
import SwiftData

/// SwiftData model for locally cached photos
@Model
final class CachedPhoto {
    @Attribute(.unique) var id: Int
    var imagekitFilePath: String
    var url: String
    var thumbnailUrl: String
    var caption: String?
    var width: Int?
    var height: Int?
    var uploadedAt: String
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var isPrimary: Bool
    var fileSize: Int
    var mimeType: String
    var locationId: Int
    var lastSyncedAt: Date
    
    init(
        id: Int,
        imagekitFilePath: String,
        url: String,
        thumbnailUrl: String,
        caption: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        uploadedAt: String,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil,
        isPrimary: Bool = false,
        fileSize: Int,
        mimeType: String,
        locationId: Int,
        lastSyncedAt: Date = Date()
    ) {
        self.id = id
        self.imagekitFilePath = imagekitFilePath
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.caption = caption
        self.width = width
        self.height = height
        self.uploadedAt = uploadedAt
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
        self.isPrimary = isPrimary
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.locationId = locationId
        self.lastSyncedAt = lastSyncedAt
    }
    
    /// Convert to API Photo model
    func toPhoto() -> Photo {
        return Photo(
            id: id,
            imagekitFilePath: imagekitFilePath,
            url: url,
            thumbnailUrl: thumbnailUrl,
            caption: caption,
            width: width,
            height: height,
            uploadedAt: uploadedAt,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude,
            isPrimary: isPrimary,
            fileSize: fileSize,
            mimeType: mimeType
        )
    }
    
    /// Create from API Photo model
    static func from(_ photo: Photo, locationId: Int) -> CachedPhoto {
        return CachedPhoto(
            id: photo.id,
            imagekitFilePath: photo.imagekitFilePath,
            url: photo.url,
            thumbnailUrl: photo.thumbnailUrl,
            caption: photo.caption,
            width: photo.width,
            height: photo.height,
            uploadedAt: photo.uploadedAt,
            gpsLatitude: photo.gpsLatitude,
            gpsLongitude: photo.gpsLongitude,
            isPrimary: photo.isPrimary,
            fileSize: photo.fileSize,
            mimeType: photo.mimeType,
            locationId: locationId
        )
    }
}
