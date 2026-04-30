import Foundation
import UIKit
import CoreLocation

/// Phase 1b — Upload queue for the new photo pipeline.
///
/// Single responsibility: accept compressed-photo upload jobs, run them with
/// bounded concurrency, surface per-job progress + outcome via an `AsyncStream`
/// of `Event`s, and support cancellation + retry.
///
/// Backed by an `actor` so callers from any context can enqueue safely.
/// Uses the existing `PhotoUploadService` for the actual HTTP work.
actor PhotoUploadQueue {

    // MARK: - Public Types

    /// A single upload task tracked by the queue.
    struct Job: Identifiable, Equatable {
        let id: UUID                 // Matches the originating PipelinePhoto.id
        let locationId: Int
        let caption: String?
        let exif: EXIFMetadata?
        let attempts: Int

        static func == (lhs: Job, rhs: Job) -> Bool { lhs.id == rhs.id }
    }

    /// Lifecycle events emitted to subscribers.
    enum Event: Equatable {
        case enqueued(jobId: UUID)
        case started(jobId: UUID)
        case progress(jobId: UUID, fraction: Double)
        case completed(jobId: UUID, photo: Photo)
        case failed(jobId: UUID, reason: String, retryable: Bool)
        case cancelled(jobId: UUID)

        // Photo isn't Equatable; fall back to id+stage comparison
        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case (.enqueued(let a), .enqueued(let b)): return a == b
            case (.started(let a), .started(let b)): return a == b
            case (.progress(let a, let af), .progress(let b, let bf)):
                return a == b && af == bf
            case (.completed(let a, let pa), .completed(let b, let pb)):
                return a == b && pa.id == pb.id
            case (.failed(let a, let ra, let xa), .failed(let b, let rb, let xb)):
                return a == b && ra == rb && xa == xb
            case (.cancelled(let a), .cancelled(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Configuration

    /// Maximum simultaneous upload tasks.
    let maxConcurrent: Int

    /// Maximum automatic retries per job before failing as non-retryable.
    let maxAutoRetries: Int

    // MARK: - State

    private var pending: [(Job, Data)] = []
    private var running: [UUID: Task<Void, Never>] = [:]
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    private let uploader: PhotoUploadServicing

    // MARK: - Init

    /// `PhotoUploadServicing` conformers are `@MainActor`-isolated, so they
    /// must be constructed by a main-actor caller (e.g. the coordinator) and
    /// injected here. Tests pass a mock conformer.
    init(
        uploader: PhotoUploadServicing,
        maxConcurrent: Int = 2,
        maxAutoRetries: Int = 2
    ) {
        self.uploader = uploader
        self.maxConcurrent = maxConcurrent
        self.maxAutoRetries = maxAutoRetries
    }

    // MARK: - Subscription

    /// Subscribe to lifecycle events. Multiple subscribers are supported.
    /// Each subscriber receives all events from this point forward.
    nonisolated func events() -> AsyncStream<Event> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<Event>.Continuation) {
        continuations[id] = continuation
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func emit(_ event: Event) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    // MARK: - Enqueue

    /// Enqueue a compressed photo for upload. The `jobId` should equal the
    /// `PipelinePhoto.id` so consumers can correlate stage updates.
    func enqueue(
        jobId: UUID,
        compressedData: Data,
        locationId: Int,
        caption: String?,
        exif: EXIFMetadata?
    ) {
        let job = Job(
            id: jobId,
            locationId: locationId,
            caption: caption,
            exif: exif,
            attempts: 0
        )
        pending.append((job, compressedData))
        emit(.enqueued(jobId: jobId))
        pump()
    }

    // MARK: - Cancellation

    /// Cancel a specific job (running or pending).
    func cancel(jobId: UUID) {
        pending.removeAll { $0.0.id == jobId }
        if let task = running.removeValue(forKey: jobId) {
            task.cancel()
        }
        emit(.cancelled(jobId: jobId))
    }

    /// Cancel everything.
    func cancelAll() {
        let pendingIds = pending.map { $0.0.id }
        pending.removeAll()
        for (id, task) in running {
            task.cancel()
            emit(.cancelled(jobId: id))
        }
        running.removeAll()
        for id in pendingIds { emit(.cancelled(jobId: id)) }
    }

    // MARK: - Inspection

    var pendingCount: Int { pending.count }
    var runningCount: Int { running.count }
    var inFlightCount: Int { pending.count + running.count }

    // MARK: - Worker Pump

    private func pump() {
        while running.count < maxConcurrent, let (job, data) = pending.first {
            pending.removeFirst()
            startJob(job, data: data)
        }
    }

    private func startJob(_ job: Job, data: Data) {
        emit(.started(jobId: job.id))

        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.run(job: job, data: data)
        }
        running[job.id] = task
    }

    private func run(job: Job, data: Data) async {
        do {
            try Task.checkCancellation()

            // Phase 1d: skip the Data → UIImage → re-compress round-trip.
            // We already have valid compressed JPEG bytes from
            // PhotoCompressionService; send them verbatim.
            let location: CLLocation? = {
                if let lat = job.exif?.latitude, let lng = job.exif?.longitude {
                    return CLLocation(latitude: lat, longitude: lng)
                }
                return nil
            }()

            emit(.progress(jobId: job.id, fraction: 0.1))

            let photo = try await uploader.uploadCompressedPhoto(
                data: data,
                filename: "photo_\(job.id.uuidString).jpg",
                locationId: job.locationId,
                location: location,
                caption: job.caption,
                exifMetadata: job.exif
            )

            emit(.progress(jobId: job.id, fraction: 1.0))
            emit(.completed(jobId: job.id, photo: photo))
            finishJob(job.id)
        } catch is CancellationError {
            emit(.cancelled(jobId: job.id))
            finishJob(job.id)
        } catch {
            // Decide whether to retry
            let nextAttempts = job.attempts + 1
            let retryable = isRetryable(error: error)
            if retryable, nextAttempts <= maxAutoRetries {
                let backoff = UInt64(pow(2.0, Double(nextAttempts))) * 500_000_000  // 1s, 2s, 4s…
                #if DEBUG
                if ConfigLoader.shared.enableDebugLogging {
                    print("[PhotoUploadQueue] Job \(job.id) failed (attempt \(nextAttempts)), retrying in \(backoff / 1_000_000_000)s: \(error)")
                }
                #endif
                try? await Task.sleep(nanoseconds: backoff)
                let retried = Job(
                    id: job.id,
                    locationId: job.locationId,
                    caption: job.caption,
                    exif: job.exif,
                    attempts: nextAttempts
                )
                running.removeValue(forKey: job.id)
                pending.insert((retried, data), at: 0)
                pump()
                return
            }
            emit(.failed(jobId: job.id, reason: error.localizedDescription, retryable: retryable))
            finishJob(job.id)
        }
    }

    private func finishJob(_ id: UUID) {
        running.removeValue(forKey: id)
        pump()
    }

    /// URL/network errors are retryable. Auth/validation errors are not.
    private func isRetryable(error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dnsLookupFailed, .cannotConnectToHost, .cannotFindHost:
                return true
            default:
                return false
            }
        }
        if error is PhotoUploadError {
            return false  // App-level errors (compression, auth) — user must fix
        }
        return true
    }
}
