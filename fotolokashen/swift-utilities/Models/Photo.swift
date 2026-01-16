import Foundation

/// Photo model matching backend API response
struct Photo: Codable, Identifiable {
    let id: Int
    let imagekitFilePath: String
    let url: String
    let thumbnailUrl: String
    let caption: String?
    let width: Int?
    let height: Int?
    let uploadedAt: String
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let isPrimary: Bool
    let fileSize: Int?
    let mimeType: String?
    
    /// Photo URL
    var photoURL: URL? {
        URL(string: url)
    }
    
    /// Thumbnail URL
    var thumbnail: URL? {
        URL(string: thumbnailUrl)
    }
    
    /// Has GPS data
    var hasGPS: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }
    
    /// GPS coordinates
    var coordinates: (lat: Double, lng: Double)? {
        guard let lat = gpsLatitude, let lng = gpsLongitude else {
            return nil
        }
        return (lat, lng)
    }
    
    /// Uploaded date
    var uploadDate: Date? {
        ISO8601DateFormatter().date(from: uploadedAt)
    }
    
    /// File size formatted
    var fileSizeFormatted: String? {
        guard let size = fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    /// Aspect ratio
    var aspectRatio: CGFloat? {
        guard let w = width, let h = height, h > 0 else { return nil }
        return CGFloat(w) / CGFloat(h)
    }
}

// MARK: - Request Upload Response

struct RequestUploadResponse: Codable {
    let photoId: Int
    let uploadUrl: String
    let uploadToken: String
    let signature: String
    let expire: Int
    let fileName: String
    let folder: String
    let publicKey: String
    
    /// Upload URL
    var url: URL? {
        URL(string: uploadUrl)
    }
    
    /// Is expired
    var isExpired: Bool {
        Date().timeIntervalSince1970 > Double(expire)
    }
}

// MARK: - Request Upload Request

struct RequestUploadRequest: Codable {
    let filename: String
    let mimeType: String
    let size: Int
    let width: Int?
    let height: Int?
    let capturedAt: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let gpsAltitude: Double?
    let gpsAccuracy: Double?
    let cameraMake: String?
    let cameraModel: String?
    let iso: Int?
    let focalLength: String?
    let aperture: String?
    let shutterSpeed: String?
}

// MARK: - Confirm Upload Request

struct ConfirmUploadRequest: Codable {
    let imagekitFileId: String
    let imagekitUrl: String
}

// MARK: - Confirm Upload Response

struct ConfirmUploadResponse: Codable {
    let success: Bool
    let photo: PhotoConfirmation
}

struct PhotoConfirmation: Codable {
    let id: Int
    let imagekitFilePath: String
    let url: String
    let uploadedAt: String
}

// MARK: - ImageKit Upload Response

struct ImageKitUploadResponse: Codable {
    let fileId: String
    let name: String
    let url: String
    let thumbnailUrl: String
    let width: Int
    let height: Int
    let size: Int
}

// MARK: - Equatable

extension Photo: Equatable {
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension Photo: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Example JSON Response
/*
 {
   "id": 789,
   "imagekitFilePath": "/production/locations/456/photo_789.jpg",
   "url": "https://ik.imagekit.io/rgriola/production/locations/456/photo_789.jpg",
   "thumbnailUrl": "https://ik.imagekit.io/rgriola/production/locations/456/photo_789.jpg?tr=w-400,h-400,c-at_max,fo-auto,q-80",
   "caption": null,
   "width": 3000,
   "height": 2000,
   "uploadedAt": "2026-01-14T19:05:00Z",
   "gpsLatitude": 37.7749,
   "gpsLongitude": -122.4194,
   "isPrimary": false,
   "fileSize": 1500000,
   "mimeType": "image/jpeg"
 }
 */
