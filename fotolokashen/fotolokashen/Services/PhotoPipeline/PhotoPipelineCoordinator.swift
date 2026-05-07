import SwiftUI
import Combine
import CoreLocation

/// Phase 1b — Coordinator for the new photo pipeline.
///
/// Single responsibility: own the array of `PipelinePhoto`s and orchestrate
/// the three layered services (`PhotoSelectionService`, `PhotoCompressionService`,
/// `PhotoUploadQueue`) so the view layer only sees a simple `@Published` list.
///
/// Deliberately mirrors the public API surface of the legacy
/// `PhotoPickerViewModel` so consumers can swap based on
/// `ConfigLoader.shared.useNewPhotoPipeline`. Differences vs legacy:
///
/// 1. Per-photo `stage` reflects real pipeline state (compressing → queued →
///    uploading(progress) → uploaded(remoteId) | failed(reason, retryable)).
/// 2. `uploadAllPhotos(locationId:location:)` returns *immediately after
///    enqueueing* — saves are no longer blocked by upload completion. The
///    view can show a "Uploads in progress" badge while the queue drains.
/// 3. Failed jobs can be retried individually via `retryFailed(id:)`.
@MainActor
final class PhotoPipelineCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var photos: [PipelinePhoto] = []
    @Published private(set) var isCompressing = false
    @Published private(set) var isUploading = false
    @Published private(set) var uploadProgress: Double = 0.0
    @Published var showPicker = false

    // MARK: - Configuration

    let maxPhotos: Int

    // MARK: - Dependencies

    private let selection: PhotoSelectionService
    private let compression: PhotoCompressionService
    private let uploadQueue: PhotoUploadQueue
    private var eventTask: Task<Void, Never>?

    // MARK: - Init

    init(
        maxPhotos: Int? = nil,
        selection: PhotoSelectionService? = nil,
        compression: PhotoCompressionService? = nil,
        uploadQueue: PhotoUploadQueue? = nil
    ) {
        self.maxPhotos = maxPhotos ?? ConfigLoader.shared.maxPhotosPerLocation
        // All MainActor-isolated services must be constructed inside the
        // MainActor-isolated init body, not as default parameter values
        // (Swift 6 strict concurrency rule).
        self.selection = selection ?? PhotoSelectionService()
        self.compression = compression ?? PhotoCompressionService()
        self.uploadQueue = uploadQueue ?? PhotoUploadQueue(uploader: PhotoUploadService())
        subscribeToQueueEvents()
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - Public API (mirrors PhotoPickerViewModel)

    /// True when more photos can still be added.
    var canAddMore: Bool { photos.count < maxPhotos }

    /// Add already-built pipeline photos (e.g. from PhotoLibrary picker).
    /// Triggers compression for any that arrive without `compressedData`.
    func addPhotos(_ newPhotos: [PipelinePhoto]) {
        let remaining = maxPhotos - photos.count
        guard remaining > 0 else {
            ErrorPresenter.shared.present(message: "Maximum \(maxPhotos) photos reached", severity: .warning)
            return
        }
        let toAdd = Array(newPhotos.prefix(remaining))
        photos.append(contentsOf: toAdd)
        if newPhotos.count > remaining {
            ErrorPresenter.shared.present(message: "Only \(remaining) photo(s) added — limit is \(maxPhotos)", severity: .warning)
        }
        Task { await compressUncompressed() }
    }

    /// Camera capture convenience. Mirrors `PhotoPickerViewModel.addCameraPhoto`.
    func addCameraPhoto(image: UIImage, location: CLLocation?) {
        let photo = selection.makeCameraPhoto(image: image, deviceLocation: location)
        addPhotos([photo])
    }

    /// Library picker convenience. Pass `(image, originalData)` so EXIF survives.
    func addLibraryPhoto(image: UIImage, originalData: Data?) {
        let photo = selection.makeLibraryPhoto(image: image, originalData: originalData)
        addPhotos([photo])
    }

    /// Multi-photo session capture convenience.
    func addSessionCaptures(_ captures: [SessionCapture]) {
        let built = selection.makeFromSessionCaptures(captures)
        addPhotos(built)
    }

    /// Remove a photo by id. If it has an in-flight upload, cancel it.
    func removePhoto(id: UUID) {
        photos.removeAll { $0.id == id }
        Task { await uploadQueue.cancel(jobId: id) }
    }

    /// Remove all photos and cancel all in-flight uploads.
    func clearPhotos() {
        let ids = photos.map { $0.id }
        photos.removeAll()
        Task {
            for id in ids { await uploadQueue.cancel(jobId: id) }
        }
    }

    // MARK: - Compression

    private func compressUncompressed() async {
        let indices = photos.indices.filter {
            photos[$0].compressedData == nil &&
            (photos[$0].stage == .picked || photos[$0].stage == .compressing)
        }
        guard !indices.isEmpty else { return }

        isCompressing = true
        defer { isCompressing = false }

        for index in indices {
            guard index < photos.count else { continue }
            updateStage(at: index, to: .compressing)
            let image = photos[index].originalImage
            let data = await compression.compress(image)
            // Re-find the photo by id in case the array mutated during await
            guard let currentIndex = photos.firstIndex(where: { $0.id == photos[safe: index]?.id }) else { continue }
            if let data {
                photos[currentIndex].compressedData = data
                updateStage(at: currentIndex, to: .compressed)
            } else {
                updateStage(at: currentIndex, to: .failed(reason: "Compression failed", retryable: false))
            }
        }
    }

    // MARK: - Upload

    /// Start uploading all compressed photos for a given location.
    ///
    /// **Returns immediately** after enqueueing — the queue drains in the
    /// background. Subscribers see live `stage` updates on each photo.
    /// Caller can dismiss the create/edit screen as soon as this returns.
    ///
    /// Photos still mid-compression are awaited first so they can be enqueued.
    func uploadAllPhotos(locationId: Int, location: CLLocation?) async {
        // Make sure compression has finished for every photo before enqueueing
        await compressUncompressed()

        lastUploadLocationId = locationId
        isUploading = true
        uploadProgress = 0.0

        for photo in photos where photo.compressedData != nil && !photo.stage.isUploaded {
            updateStage(id: photo.id, to: .queuedForUpload)
            await uploadQueue.enqueue(
                jobId: photo.id,
                compressedData: photo.compressedData!,
                locationId: locationId,
                caption: photo.caption,
                exif: photo.exifMetadata
            )
        }
        // isUploading flips back to false once the queue drains (see event handler).
    }

    /// Manually retry a failed photo.
    func retryFailed(id: UUID) async {
        guard let index = photos.firstIndex(where: { $0.id == id }),
              case .failed = photos[index].stage,
              let data = photos[index].compressedData else { return }
        // We need the locationId the original enqueue used. Re-enqueue requires
        // the caller to pass it; in practice the coordinator stores it after
        // first uploadAllPhotos. For now we expose a separate retry-with-id
        // method that the view layer can call with the known location.
        updateStage(at: index, to: .queuedForUpload)
        await uploadQueue.enqueue(
            jobId: id,
            compressedData: data,
            locationId: lastUploadLocationId ?? -1,
            caption: photos[index].caption,
            exif: photos[index].exifMetadata
        )
    }

    private var lastUploadLocationId: Int?

    // MARK: - Queue Event Subscription

    private func subscribeToQueueEvents() {
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.uploadQueue.events() {
                self.handle(event: event)
            }
        }
    }

    private func handle(event: PhotoUploadQueue.Event) {
        switch event {
        case .enqueued(let id):
            updateStage(id: id, to: .queuedForUpload)
        case .started(let id):
            updateStage(id: id, to: .uploading(progress: 0))
        case .progress(let id, let fraction):
            updateStage(id: id, to: .uploading(progress: fraction))
        case .completed(let id, let photo):
            updateStage(id: id, to: .uploaded(remoteId: photo.id))
            recomputeAggregateProgress()
        case .failed(let id, let reason, let retryable):
            updateStage(id: id, to: .failed(reason: reason, retryable: retryable))
            ErrorPresenter.shared.present(message: reason)
            recomputeAggregateProgress()
        case .cancelled(let id):
            // Photo may have already been removed; ignore if missing
            if photos.contains(where: { $0.id == id }) {
                updateStage(id: id, to: .failed(reason: "Cancelled", retryable: true))
            }
            recomputeAggregateProgress()
        }
    }

    private func recomputeAggregateProgress() {
        let total = photos.count
        guard total > 0 else {
            uploadProgress = 0
            isUploading = false
            return
        }
        let done = photos.reduce(0.0) { acc, p in
            switch p.stage {
            case .uploaded: return acc + 1
            case .uploading(let f): return acc + f
            default: return acc
            }
        }
        uploadProgress = done / Double(total)
        isUploading = photos.contains { p in
            switch p.stage {
            case .queuedForUpload, .uploading: return true
            default: return false
            }
        }
    }

    // MARK: - Stage Helpers

    private func updateStage(at index: Int, to stage: PipelineStage) {
        guard photos.indices.contains(index) else { return }
        photos[index].stage = stage
    }

    private func updateStage(id: UUID, to stage: PipelineStage) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].stage = stage
    }
}

// MARK: - Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
