import Foundation
import CoreLocation

/// Phase 4a — Protocol surface for `PhotoUploadService` so that
/// `PhotoUploadQueue` can be unit-tested with an in-process mock.
///
/// Intentionally minimal — only the single entry point the queue uses today.
/// New surface area should be added here when (and only when) the queue grows
/// to use it.
@MainActor
protocol PhotoUploadServicing: AnyObject {
    func uploadCompressedPhoto(
        data compressedData: Data,
        filename: String?,
        locationId: Int,
        location: CLLocation?,
        caption: String?,
        exifMetadata: EXIFMetadata?
    ) async throws -> Photo
}

extension PhotoUploadService: PhotoUploadServicing {}
