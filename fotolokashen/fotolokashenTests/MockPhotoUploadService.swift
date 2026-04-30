import Foundation
import CoreLocation
@testable import fotolokashen

/// Phase 4a — In-process mock for `PhotoUploadServicing`.
///
/// Programmable per-call: `responses` is consumed FIFO. If exhausted, calls
/// fall back to `defaultResponse`. Each call records its inputs in `calls`.
/// `delay` simulates network latency so the queue's concurrency / retry
/// scheduling can be observed deterministically.
@MainActor
final class MockPhotoUploadService: PhotoUploadServicing {

    enum Response {
        case success(Photo)
        case failure(Error)
    }

    struct Call: Equatable {
        let locationId: Int
        let filename: String?
        let dataSize: Int
        let caption: String?
    }

    var responses: [Response] = []
    var defaultResponse: Response = .failure(URLError(.unknown))
    var delay: TimeInterval = 0
    private(set) var calls: [Call] = []

    func uploadCompressedPhoto(
        data compressedData: Data,
        filename: String?,
        locationId: Int,
        location: CLLocation?,
        caption: String?,
        exifMetadata: EXIFMetadata?
    ) async throws -> Photo {
        calls.append(Call(
            locationId: locationId,
            filename: filename,
            dataSize: compressedData.count,
            caption: caption
        ))

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        let response: Response
        if responses.isEmpty {
            response = defaultResponse
        } else {
            response = responses.removeFirst()
        }

        switch response {
        case .success(let photo):
            return photo
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Helpers

    static func samplePhoto(id: Int = 1) -> Photo {
        // Build the smallest possible Photo via JSON to avoid coupling to
        // initializer churn. Photo is Codable, so this stays robust.
        let json = """
        {
            "id": \(id),
            "imagekitFilePath": "/test/\(id).jpg",
            "url": "https://example.com/\(id).jpg",
            "thumbnailUrl": "https://example.com/\(id)-thumb.jpg",
            "isPrimary": false,
            "uploadedAt": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try! decoder.decode(Photo.self, from: json)
    }
}
