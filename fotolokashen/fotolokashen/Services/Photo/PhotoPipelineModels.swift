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

// MARK: - Pipeline Stage

/// Per-photo state machine for the new `PhotoPipelineCoordinator` (Phase 1b).
/// The legacy `PhotoPickerViewModel` ignores `stage` and continues to work as before.
enum PipelineStage: Equatable {
    /// Just picked / captured. Awaiting compression.
    case picked
    /// Compression in progress (background actor).
    case compressing
    /// Compressed JPEG ready in `PipelinePhoto.compressedData`.
    case compressed
    /// Enqueued in `PhotoUploadQueue` waiting for a worker slot.
    case queuedForUpload
    /// Currently uploading. Progress is 0.0...1.0.
    case uploading(progress: Double)
    /// Server returned a Photo. `remoteId` is the persisted photo ID.
    case uploaded(remoteId: Int)
    /// Pipeline error. `retryable` indicates whether the user can manually retry.
    case failed(reason: String, retryable: Bool)

    /// True when the stage represents finished work (success or terminal failure).
    var isTerminal: Bool {
        switch self {
        case .uploaded, .failed: return true
        default: return false
        }
    }

    /// True for the success terminal state.
    var isUploaded: Bool {
        if case .uploaded = self { return true }
        return false
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

    /// Phase 1b state machine. Legacy `PhotoPickerViewModel` leaves this at `.picked`.
    var stage: PipelineStage = .picked

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
        exif: EXIFMetadata? = nil,
        stage: PipelineStage = .picked
    ) {
        self.id = UUID()
        self.source = source
        self.originalImage = image
        self.exifMetadata = exif
        self.stage = stage
    }
}
