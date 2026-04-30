import Foundation
import UIKit

/// Phase 1b — Compression layer of the new photo pipeline.
///
/// Single responsibility: compress a `UIImage` to JPEG `Data` according to the
/// configured `ImageCompressor.Config`. Runs as an `actor` so callers can fan
/// out concurrent compress requests without blocking the main thread.
///
/// Stateless aside from the injected config — safe to share a single instance.
actor PhotoCompressionService {

    // MARK: - Properties

    private let config: ImageCompressor.Config

    // MARK: - Init

    init(config: ImageCompressor.Config = ConfigLoader.shared.imageCompressionConfig) {
        self.config = config
    }

    // MARK: - Compression

    /// Compress a single image to JPEG Data using the configured strategy.
    /// Returns nil if compression fails (e.g. invalid image).
    func compress(_ image: UIImage) async -> Data? {
        // ImageCompressor.compress is CPU-heavy and synchronous.
        // The actor isolation already serializes calls per-instance; we still
        // detach to a userInitiated task so a single compress doesn't starve
        // other actor work.
        await Task.detached(priority: .userInitiated) {
            ImageCompressor.compress(image, config: self.config)
        }.value
    }

    /// Compress a batch of images concurrently. Order is preserved.
    /// Returns `(originalIndex, Data?)` pairs so callers can correlate failures.
    func compressBatch(_ images: [UIImage]) async -> [(index: Int, data: Data?)] {
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask(priority: .userInitiated) {
                    let data = ImageCompressor.compress(image, config: self.config)
                    return (index, data)
                }
            }
            var results: [(Int, Data?)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }
        }
    }
}
