import XCTest
@testable import fotolokashen

/// Phase 4a — `PhotoUploadQueue` state-machine + retry coverage.
final class PhotoUploadQueueTests: XCTestCase {

    // MARK: - Helpers

    /// Subscribe to `events()` BEFORE running `action`, then drain until the
    /// predicate returns true (or `timeout` elapses). The queue does not
    /// buffer events for late subscribers, so this ordering is critical.
    private func collectEvents(
        on queue: PhotoUploadQueue,
        timeout: TimeInterval = 5.0,
        until predicate: @escaping ([PhotoUploadQueue.Event]) -> Bool,
        while action: @escaping () async -> Void
    ) async -> [PhotoUploadQueue.Event] {
        let stream = queue.events()
        let collector = Task { () -> [PhotoUploadQueue.Event] in
            var collected: [PhotoUploadQueue.Event] = []
            for await event in stream {
                collected.append(event)
                if predicate(collected) { return collected }
            }
            return collected
        }
        // Give the subscription a beat to register inside the actor.
        try? await Task.sleep(nanoseconds: 50_000_000)
        await action()

        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            collector.cancel()
        }
        let result = await collector.value
        timer.cancel()
        return result
    }

    private func sampleData(_ size: Int = 1024) -> Data {
        Data(repeating: 0xFF, count: size)
    }

    // MARK: - Happy Path

    @MainActor
    func testEnqueueRunsAndCompletes() async {
        let mock = MockPhotoUploadService()
        let photo = MockPhotoUploadService.samplePhoto(id: 42)
        mock.responses = [.success(photo)]

        let queue = PhotoUploadQueue(uploader: mock, maxConcurrent: 1, maxAutoRetries: 0)
        let jobId = UUID()

        let events = await collectEvents(on: queue, until: { events in
            events.contains { if case .completed = $0 { return true } else { return false } }
        }, while: {
            await queue.enqueue(
                jobId: jobId,
                compressedData: self.sampleData(),
                locationId: 7,
                caption: "hello",
                exif: nil
            )
        })

        let kinds = events.map(eventKind)
        XCTAssertEqual(kinds.prefix(3), ["enqueued", "started", "progress"])
        XCTAssertTrue(kinds.contains("completed"))
        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertEqual(mock.calls.first?.locationId, 7)
        XCTAssertEqual(mock.calls.first?.caption, "hello")
    }

    // MARK: - Retry Behavior

    @MainActor
    func testRetriesTransientNetworkErrorThenSucceeds() async {
        let mock = MockPhotoUploadService()
        let photo = MockPhotoUploadService.samplePhoto(id: 1)
        // First two calls fail with a retryable network error, third succeeds.
        mock.responses = [
            .failure(URLError(.timedOut)),
            .failure(URLError(.networkConnectionLost)),
            .success(photo)
        ]

        let queue = PhotoUploadQueue(uploader: mock, maxConcurrent: 1, maxAutoRetries: 2)
        let jobId = UUID()

        // Backoff is 1s + 2s — give it 8s to complete.
        let events = await collectEvents(on: queue, timeout: 8.0, until: { events in
            events.contains { if case .completed = $0 { return true } else { return false } }
        }, while: {
            await queue.enqueue(
                jobId: jobId,
                compressedData: self.sampleData(),
                locationId: 1,
                caption: nil,
                exif: nil
            )
        })

        XCTAssertEqual(mock.calls.count, 3, "Expected 3 attempts (2 retries + success)")
        XCTAssertTrue(events.contains { if case .completed = $0 { return true } else { return false } })
        XCTAssertFalse(events.contains { if case .failed = $0 { return true } else { return false } },
                       "Should not emit .failed when a retry succeeds")
    }

    @MainActor
    func testGivesUpAfterMaxRetriesAndEmitsFailed() async {
        let mock = MockPhotoUploadService()
        mock.defaultResponse = .failure(URLError(.timedOut))

        let queue = PhotoUploadQueue(uploader: mock, maxConcurrent: 1, maxAutoRetries: 1)
        let jobId = UUID()

        // 1 initial + 1 retry, backoff 1s.
        let events = await collectEvents(on: queue, timeout: 5.0, until: { events in
            events.contains { if case .failed = $0 { return true } else { return false } }
        }, while: {
            await queue.enqueue(
                jobId: jobId,
                compressedData: self.sampleData(),
                locationId: 1,
                caption: nil,
                exif: nil
            )
        })

        XCTAssertEqual(mock.calls.count, 2, "Expected initial + 1 auto-retry then give up")
        let failedEvent = events.first { if case .failed = $0 { return true } else { return false } }
        guard case .failed(_, _, let retryable) = failedEvent else {
            XCTFail("Expected .failed event")
            return
        }
        XCTAssertTrue(retryable, "URLError should be marked retryable for manual retry UI")
    }

    @MainActor
    func testNonRetryableErrorFailsImmediately() async {
        let mock = MockPhotoUploadService()
        mock.defaultResponse = .failure(URLError(.userAuthenticationRequired))

        let queue = PhotoUploadQueue(uploader: mock, maxConcurrent: 1, maxAutoRetries: 5)
        let jobId = UUID()

        let events = await collectEvents(on: queue, timeout: 2.0, until: { events in
            events.contains { if case .failed = $0 { return true } else { return false } }
        }, while: {
            await queue.enqueue(
                jobId: jobId,
                compressedData: self.sampleData(),
                locationId: 1,
                caption: nil,
                exif: nil
            )
        })

        XCTAssertEqual(mock.calls.count, 1, "Non-retryable error should fail immediately")
        guard case .failed(_, _, let retryable) = events.first(where: {
            if case .failed = $0 { return true } else { return false }
        }) else {
            XCTFail("Expected .failed event")
            return
        }
        XCTAssertFalse(retryable, "userAuthenticationRequired is not retryable")
    }

    // MARK: - Cancellation

    @MainActor
    func testCancelPendingJobEmitsCancelled() async {
        let mock = MockPhotoUploadService()
        mock.delay = 1.0  // Keep the first job running so the second stays pending.
        mock.defaultResponse = .success(MockPhotoUploadService.samplePhoto())

        let queue = PhotoUploadQueue(uploader: mock, maxConcurrent: 1, maxAutoRetries: 0)
        let firstId = UUID()
        let secondId = UUID()

        let events = await collectEvents(on: queue, timeout: 3.0, until: { events in
            events.contains { if case .cancelled(let id) = $0 { return id == secondId } else { return false } }
        }, while: {
            await queue.enqueue(jobId: firstId, compressedData: self.sampleData(), locationId: 1, caption: nil, exif: nil)
            await queue.enqueue(jobId: secondId, compressedData: self.sampleData(), locationId: 1, caption: nil, exif: nil)
            // Cancel the second (pending) job before the first finishes.
            await queue.cancel(jobId: secondId)
        })

        XCTAssertTrue(events.contains { if case .cancelled(let id) = $0 { return id == secondId } else { return false } })
    }

    // MARK: - Concurrency Bound

    @MainActor
    func testRespectsMaxConcurrent() async {
        let mock = MockPhotoUploadService()
        mock.delay = 0.4
        mock.defaultResponse = .success(MockPhotoUploadService.samplePhoto())

        let queue = PhotoUploadQueue(uploader: mock, maxConcurrent: 2, maxAutoRetries: 0)
        for _ in 0..<5 {
            await queue.enqueue(
                jobId: UUID(),
                compressedData: sampleData(),
                locationId: 1,
                caption: nil,
                exif: nil
            )
        }

        // Right after enqueuing, at most 2 should be running.
        let runningRightAway = await queue.runningCount
        let inFlight = await queue.inFlightCount
        XCTAssertLessThanOrEqual(runningRightAway, 2, "maxConcurrent=2 must be honored")
        XCTAssertEqual(inFlight, 5)
    }

    // MARK: - Helpers

    private func eventKind(_ event: PhotoUploadQueue.Event) -> String {
        switch event {
        case .enqueued: return "enqueued"
        case .started: return "started"
        case .progress: return "progress"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        }
    }
}
