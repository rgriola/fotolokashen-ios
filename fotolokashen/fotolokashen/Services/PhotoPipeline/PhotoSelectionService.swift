import Foundation
import UIKit
import CoreLocation

/// Phase 1b — Selection layer of the new photo pipeline.
///
/// Single responsibility: turn raw inputs (PHPicker results, camera captures,
/// session captures) into `PipelinePhoto` values with EXIF extracted and
/// `stage = .picked`. Knows nothing about compression, queueing, or upload.
///
/// All public methods are pure and synchronous from the caller's perspective —
/// EXIF extraction happens inline using `EXIFExtractor` (already optimized).
@MainActor
struct PhotoSelectionService {

    // MARK: - Camera

    /// Build a pipeline photo from a single camera capture.
    /// Falls back to device GPS when EXIF lacks coordinates.
    func makeCameraPhoto(image: UIImage, deviceLocation: CLLocation?) -> PipelinePhoto {
        var exif = EXIFExtractor.extract(from: image) ?? EXIFMetadata()

        if !exif.hasGPS, let loc = deviceLocation {
            exif.latitude = loc.coordinate.latitude
            exif.longitude = loc.coordinate.longitude
            exif.altitude = loc.altitude
        }

        // Camera shots from iPhone are always Apple
        if exif.cameraMake == nil {
            exif.cameraMake = "Apple"
            exif.cameraModel = UIDevice.current.model
        }

        return PipelinePhoto(source: .camera, image: image, exif: exif, stage: .picked)
    }

    // MARK: - Photo Library

    /// Build a pipeline photo from a `(image, data)` pair returned by the picker.
    /// Prefers EXIF extracted from the original `Data` (preserves all tags) and
    /// falls back to extracting from the rendered `UIImage`.
    func makeLibraryPhoto(image: UIImage, originalData: Data?) -> PipelinePhoto {
        let exif: EXIFMetadata? = {
            if let data = originalData, let extracted = EXIFExtractor.extract(from: data) {
                return extracted
            }
            return EXIFExtractor.extract(from: image)
        }()

        return PipelinePhoto(source: .library, image: image, exif: exif, stage: .picked)
    }

    // MARK: - Session Captures

    /// Convert multi-photo camera session captures into pipeline photos.
    /// Delegates to `SessionCapture.toPipelinePhoto()` and then stamps `stage = .picked`.
    func makeFromSessionCaptures(_ captures: [SessionCapture]) -> [PipelinePhoto] {
        captures.compactMap { capture in
            guard var photo = capture.toPipelinePhoto() else { return nil }
            photo.stage = .picked
            return photo
        }
    }
}
