import SwiftUI
import Combine
import CoreLocation

/// ViewModel managing the photo pipeline: picking, compression, EXIF extraction, and upload.
/// Shared between CreateLocationView and any future view that needs photo selection + upload.
///
/// Reusable across apps — replace `ConfigLoader.shared.maxPhotosPerLocation` with your own limit.
@MainActor
class PhotoPickerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var photos: [PipelinePhoto] = []
    @Published var isCompressing = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var showPicker = false

    // MARK: - Configuration

    let maxPhotos: Int

    // MARK: - Init

    init(maxPhotos: Int? = nil) {
        self.maxPhotos = maxPhotos ?? ConfigLoader.shared.maxPhotosPerLocation
    }

    // MARK: - Photo Management

    /// Add photos from the picker or camera.
    /// Automatically compresses photos that aren't already compressed.
    func addPhotos(_ newPhotos: [PipelinePhoto]) {
        let remaining = maxPhotos - photos.count
        guard remaining > 0 else {
            errorMessage = "Maximum \(maxPhotos) photos reached"
            return
        }

        let toAdd = Array(newPhotos.prefix(remaining))
        photos.append(contentsOf: toAdd)

        // Compress any that aren't already compressed
        Task {
            await compressUncompressedPhotos()
        }

        if newPhotos.count > remaining {
            errorMessage = "Only \(remaining) photo(s) added — limit is \(maxPhotos)"
        }
    }

    /// Add a single camera-captured photo with optional GPS from the device.
    func addCameraPhoto(image: UIImage, location: CLLocation?) {
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

        let photo = PipelinePhoto(source: .camera, image: image, exif: exif)
        addPhotos([photo])
    }

    /// Remove a photo by ID.
    func removePhoto(id: UUID) {
        photos.removeAll { $0.id == id }
    }

    /// Remove all photos.
    func clearPhotos() {
        photos.removeAll()
    }

    /// Whether additional photos can be added.
    var canAddMore: Bool {
        photos.count < maxPhotos
    }

    // MARK: - Compression

    /// Compress any photos that haven't been compressed yet.
    /// Runs compression on a background thread to avoid blocking the main thread / touch events.
    private func compressUncompressedPhotos() async {
        isCompressing = true
        defer { isCompressing = false }

        for index in photos.indices {
            if photos[index].compressedData == nil {
                let image = photos[index].originalImage
                // Dispatch heavy compression to a background thread
                let compressed = await Task.detached(priority: .userInitiated) {
                    ImageCompressor.compress(image)
                }.value
                // Write result back on MainActor (we're already on it)
                if index < photos.count {
                    photos[index].compressedData = compressed
                }
            }
        }
    }

    // MARK: - Upload

    /// Upload all pipeline photos to a location.
    /// Returns the array of Photo models returned by the server.
    func uploadAllPhotos(
        locationId: Int,
        location: CLLocation?
    ) async throws -> [Photo] {
        guard !photos.isEmpty else { return [] }

        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        defer {
            isUploading = false
        }

        let uploader = PhotoUploadService()
        var uploaded: [Photo] = []
        let total = Double(photos.count)

        for (index, pipelinePhoto) in photos.enumerated() {
            do {
                // Use EXIF GPS as fallback when CLLocation is nil
                let uploadLocation: CLLocation?
                if let loc = location {
                    uploadLocation = loc
                } else if let gps = pipelinePhoto.gpsCoordinate {
                    uploadLocation = CLLocation(latitude: gps.lat, longitude: gps.lng)
                } else {
                    uploadLocation = nil
                }

                let photo = try await uploader.uploadPhoto(
                    image: pipelinePhoto.originalImage,
                    locationId: locationId,
                    location: uploadLocation,
                    caption: pipelinePhoto.caption,
                    exifMetadata: pipelinePhoto.exifMetadata
                )
                uploaded.append(photo)

                uploadProgress = Double(index + 1) / total

                #if DEBUG
                if ConfigLoader.shared.enableDebugLogging {
                    print("[PhotoPipeline] Uploaded \(index + 1)/\(Int(total))")
                }
                #endif

            } catch {
                #if DEBUG
                if ConfigLoader.shared.enableDebugLogging {
                    print("[PhotoPipeline] Failed to upload photo \(index + 1): \(error)")
                }
                #endif
                // Continue uploading remaining photos
                errorMessage = "Failed to upload \(photos.count - uploaded.count) photo(s)"
            }
        }

        return uploaded
    }
}
