import Foundation
import UIKit
import CoreLocation

/// A single photo captured during a multi-photo camera session.
/// Disk-backed: the full-resolution JPEG lives at `fileURL`, while only a
/// small thumbnail is kept in memory for UI display.
struct SessionCapture: Identifiable {
    let id = UUID()

    /// Full-resolution JPEG on disk (temp directory)
    let fileURL: URL

    /// Small thumbnail for the camera's capture strip (~150×150)
    let thumbnail: UIImage

    /// Device GPS at the moment of capture (may be nil)
    let location: CLLocation?

    /// When the photo was taken
    let capturedAt: Date

    /// Load the full-resolution UIImage from disk on demand
    func loadFullImage() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Convert to a PipelinePhoto for the upload pipeline.
    /// Loads the full image from disk and extracts EXIF.
    func toPipelinePhoto() -> PipelinePhoto? {
        guard let image = loadFullImage() else { return nil }

        var exif = EXIFExtractor.extract(from: image) ?? EXIFMetadata()

        // Supplement with device GPS if EXIF has none
        if !exif.hasGPS, let loc = location {
            exif.latitude = loc.coordinate.latitude
            exif.longitude = loc.coordinate.longitude
            exif.altitude = loc.altitude
        }

        // Camera photos from iPhone are always Apple
        if exif.cameraMake == nil {
            exif.cameraMake = "Apple"
            exif.cameraModel = UIDevice.current.model
        }

        if exif.dateTaken == nil {
            exif.dateTaken = capturedAt
        }

        return PipelinePhoto(source: .camera, image: image, exif: exif)
    }
}
