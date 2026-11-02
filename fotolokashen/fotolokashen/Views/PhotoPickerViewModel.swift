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
    @Published var showPicker = false

    // MARK: - Configuration

    let maxPhotos: Int

    // MARK: - Dependencies

    private let compressionService = PhotoCompressionService()
    private let uploadQueue = PhotoUploadQueue(uploader: PhotoUploadService())
    private var queueEventTask: Task<Void, Never>?
    private var lastUploadLocationId: Int?

    // MARK: - Init

    init(maxPhotos: Int? = nil) {
        self.maxPhotos = maxPhotos ?? ConfigLoader.shared.maxPhotosPerLocation
        subscribeToQueueEvents()
    }

    deinit {
        queueEventTask?.cancel()
    }

    // MARK: - Photo Management

    /// Add photos from the picker or camera.
    /// Automatically compresses photos that aren't already compressed.
    func addPhotos(_ newPhotos: [PipelinePhoto]) {
        let remaining = maxPhotos - photos.count
        guard remaining > 0 else {
            ErrorPresenter.shared.present(message: "Maximum \(maxPhotos) photos reached", severity: .warning)
            return
        }

        let toAdd = Array(newPhotos.prefix(remaining))
        photos.append(contentsOf: toAdd)

        // Compress any that aren't already compressed
        Task {
            await compressUncompressedPhotos()
        }

        if newPhotos.count > remaining {
            ErrorPresenter.shared.present(message: "Only \(remaining) photo(s) added — limit is \(maxPhotos)", severity: .warning)
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
    /// Also updates each photo's `stage` so the grid can show a spinner while compressing.
    private func compressUncompressedPhotos() async {
        isCompressing = true
        defer { isCompressing = false }

        for index in photos.indices {
            guard index < photos.count, photos[index].compressedData == nil else { continue }
            let id = photos[index].id
            updateStage(id: id, to: .compressing)
            let image = photos[index].originalImage
            let compressed = await compressionService.compress(image)
            if let currentIndex = photos.firstIndex(where: { $0.id == id }) {
                photos[currentIndex].compressedData = compressed
                updateStage(id: id, to: compressed != nil
                    ? .compressed
                    : .failed(reason: "Compression failed", retryable: false))
            }
        }
    }

    // MARK: - Upload

    /// Upload all pipeline photos to a location through `PhotoUploadQueue`,
    /// which provides bounded concurrency and retries transient network errors.
    /// Waits for every enqueued photo to finish and returns the server photos.
    /// Per-photo `stage` updates flow in via `subscribeToQueueEvents()`.
    func uploadAllPhotos(locationId: Int) async -> [Photo] {
        guard !photos.isEmpty else { return [] }

        isUploading = true
        uploadProgress = 0.0

        defer {
            isUploading = false
        }

        // Make sure compression has finished for everything
        await compressUncompressedPhotos()

        lastUploadLocationId = locationId

        // Enqueue every photo that has compressed data
        let toEnqueue = photos.filter { $0.compressedData != nil && !$0.stage.isUploaded }
        guard !toEnqueue.isEmpty else { return [] }

        let pendingIds = Set(toEnqueue.map { $0.id })
        for photo in toEnqueue {
            updateStage(id: photo.id, to: .queuedForUpload)
            await uploadQueue.enqueue(
                jobId: photo.id,
                compressedData: photo.compressedData!,
                locationId: locationId,
                caption: photo.caption,
                exif: photo.exifMetadata
            )
        }

        // Await terminal state for every enqueued photo so the caller can
        // continue its existing post-upload flow.
        var collected: [Photo] = []
        let stream = uploadQueue.events()
        var remaining = pendingIds
        for await event in stream {
            switch event {
            case .completed(let id, let photo) where remaining.contains(id):
                collected.append(photo)
                remaining.remove(id)
            case .failed(let id, _, _) where remaining.contains(id):
                remaining.remove(id)
            case .cancelled(let id) where remaining.contains(id):
                remaining.remove(id)
            default:
                break
            }
            if remaining.isEmpty { break }
        }
        return collected
    }

    /// Manually retry a failed upload (called from `PhotoGridView` retry tap).
    func retryPhoto(id: UUID) {
        guard let photo = photos.first(where: { $0.id == id }),
              let data = photo.compressedData,
              let locationId = lastUploadLocationId else { return }
        updateStage(id: id, to: .queuedForUpload)
        Task {
            await uploadQueue.enqueue(
                jobId: id,
                compressedData: data,
                locationId: locationId,
                caption: photo.caption,
                exif: photo.exifMetadata
            )
        }
    }

    // MARK: - Queue Event Subscription

    private func subscribeToQueueEvents() {
        queueEventTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.uploadQueue.events() {
                self.handleQueueEvent(event)
            }
        }
    }

    private func handleQueueEvent(_ event: PhotoUploadQueue.Event) {
        switch event {
        case .enqueued(let id):
            updateStage(id: id, to: .queuedForUpload)
        case .started(let id):
            updateStage(id: id, to: .uploading(progress: 0))
        case .progress(let id, let fraction):
            updateStage(id: id, to: .uploading(progress: fraction))
        case .completed(let id, let photo):
            updateStage(id: id, to: .uploaded(remoteId: photo.id))
        case .failed(let id, let reason, let retryable):
            updateStage(id: id, to: .failed(reason: reason, retryable: retryable))
            ErrorPresenter.shared.present(message: reason)
        case .cancelled(let id):
            if photos.contains(where: { $0.id == id }) {
                updateStage(id: id, to: .failed(reason: "Cancelled", retryable: true))
            }
        }
    }

    // MARK: - Stage Helper

    private func updateStage(id: UUID, to stage: PipelineStage) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].stage = stage
    }
}
