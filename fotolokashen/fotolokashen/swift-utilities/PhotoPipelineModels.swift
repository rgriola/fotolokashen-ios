import Foundation
import UIKit

// MARK: - Photo Source

/// Where a photo originated — used for tracking and GPS source selection
enum PhotoSource: String, Codable {
    case camera = "CAMERA"
    case library = "LIBRARY"
}

// MARK: - EXIF Metadata

/// Extracted EXIF metadata from a photo, matching the web app's metadata capture
struct EXIFMetadata: Codable {
    // GPS
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?

    // Camera
    var cameraMake: String?
    var cameraModel: String?
    var lensMake: String?
    var lensModel: String?

    // Exposure
    var iso: Int?
    var focalLength: String?
    var aperture: String?
    var shutterSpeed: String?
    var exposureMode: String?

    // Other
    var whiteBalance: String?
    var flash: String?
    var colorSpace: String?
    var orientation: Int?
    var dateTaken: Date?

    /// Whether this metadata contains GPS coordinates
    var hasGPS: Bool {
        latitude != nil && longitude != nil
    }

    /// Convert to the metadata JSON dictionary sent in the upload multipart body
    func toUploadMetadata() -> [String: Any] {
        var dict: [String: Any] = [
            "hasGPS": hasGPS
        ]

        if let lat = latitude { dict["lat"] = lat }
        if let lng = longitude { dict["lng"] = lng }
        if let alt = altitude { dict["altitude"] = alt }

        var camera: [String: Any] = [:]
        if let make = cameraMake { camera["make"] = make }
        if let model = cameraModel { camera["model"] = model }
        if let lensMake = lensMake { camera["lensMake"] = lensMake }
        if let lensModel = lensModel { camera["lensModel"] = lensModel }
        if !camera.isEmpty { dict["camera"] = camera }

        var exif: [String: Any] = [:]
        if let iso = iso { exif["iso"] = iso }
        if let fl = focalLength { exif["focalLength"] = fl }
        if let ap = aperture { exif["aperture"] = ap }
        if let ss = shutterSpeed { exif["shutterSpeed"] = ss }
        if let em = exposureMode { exif["exposureMode"] = em }
        if let wb = whiteBalance { exif["whiteBalance"] = wb }
        if let f = flash { exif["flash"] = f }
        if let cs = colorSpace { exif["colorSpace"] = cs }
        if let o = orientation { exif["orientation"] = o }
        if let dt = dateTaken {
            exif["dateTaken"] = ISO8601DateFormatter().string(from: dt)
        }
        if !exif.isEmpty { dict["exif"] = exif }

        return dict
    }
}

// MARK: - Pipeline Photo

/// A photo being processed through the picker → compress → upload pipeline.
/// Holds the original image, compressed data, extracted EXIF, and source info.
struct PipelinePhoto: Identifiable {
    let id: UUID
    let source: PhotoSource
    let originalImage: UIImage
    var compressedData: Data?
    var exifMetadata: EXIFMetadata?
    var caption: String?

    /// Whether compression has completed
    var isCompressed: Bool { compressedData != nil }

    /// Whether EXIF extraction has completed
    var hasExif: Bool { exifMetadata != nil }

    /// GPS from EXIF (preferred) or nil
    var gpsCoordinate: (lat: Double, lng: Double)? {
        guard let meta = exifMetadata, meta.hasGPS,
              let lat = meta.latitude, let lng = meta.longitude else {
            return nil
        }
        return (lat, lng)
    }

    init(
        source: PhotoSource,
        image: UIImage,
        exif: EXIFMetadata? = nil
    ) {
        self.id = UUID()
        self.source = source
        self.originalImage = image
        self.exifMetadata = exif
    }
}
