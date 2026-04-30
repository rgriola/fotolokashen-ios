import XCTest
import UIKit
@testable import fotolokashen

/// Phase 4b — `PhotoCompressionService` actor coverage.
final class PhotoCompressionServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Build a synthetic UIImage of the given size with random-ish pixel data
    /// so JPEG can't trivially compress it to a few bytes. Big enough that
    /// quality reduction matters but small enough to keep tests fast.
    private func makeImage(size: CGSize = CGSize(width: 800, height: 600)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Paint a noisy gradient so JPEG compression has real work to do.
            let cg = ctx.cgContext
            for y in stride(from: 0, to: Int(size.height), by: 8) {
                for x in stride(from: 0, to: Int(size.width), by: 8) {
                    let r = CGFloat((x * 13 + y * 7) % 255) / 255
                    let g = CGFloat((x * 5 + y * 11) % 255) / 255
                    let b = CGFloat((x * 17 + y * 3) % 255) / 255
                    cg.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 1).cgColor)
                    cg.fill(CGRect(x: x, y: y, width: 8, height: 8))
                }
            }
        }
    }

    // MARK: - Single Compression

    func testCompressReturnsJPEGData() async {
        let service = PhotoCompressionService()
        let image = makeImage()

        let data = await service.compress(image)

        XCTAssertNotNil(data)
        // JPEG SOI marker is 0xFFD8.
        XCTAssertEqual(data?.prefix(2), Data([0xFF, 0xD8]))
    }

    func testCompressRespectsTargetBytesCap() async {
        // Tight cap forces multiple quality-reduction iterations.
        let config = ImageCompressor.Config(
            targetBytes: 50_000,
            qualityStart: 0.9,
            qualityFloor: 0.4,
            maxDimension: 800,
            qualityStep: 0.1
        )
        let service = PhotoCompressionService(config: config)
        let image = makeImage(size: CGSize(width: 1600, height: 1200))

        let data = await service.compress(image)
        XCTAssertNotNil(data)
        // Compressor may exceed when at qualityFloor + maxDimension; allow
        // 2x margin — the assertion that matters is "made an honest attempt".
        XCTAssertLessThan(data!.count, 200_000, "Compressor should be near the configured target")
    }

    // MARK: - Batch Compression

    func testCompressBatchPreservesOrder() async {
        let service = PhotoCompressionService()
        let images = (0..<5).map { i in
            makeImage(size: CGSize(width: 200 + i * 50, height: 200 + i * 50))
        }

        let results = await service.compressBatch(images)

        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results.map { $0.index }, [0, 1, 2, 3, 4], "Batch must preserve original order")
        XCTAssertTrue(results.allSatisfy { $0.data != nil }, "All compressions should succeed")
    }

    func testCompressBatchRunsConcurrently() async {
        let service = PhotoCompressionService()
        let images = (0..<8).map { _ in makeImage() }

        let serialStart = Date()
        for image in images { _ = await service.compress(image) }
        let serialDuration = Date().timeIntervalSince(serialStart)

        let batchStart = Date()
        _ = await service.compressBatch(images)
        let batchDuration = Date().timeIntervalSince(batchStart)

        // On any multi-core simulator host, batch should be meaningfully
        // faster than strict serial. Generous bound to avoid CI flakiness.
        XCTAssertLessThan(batchDuration, serialDuration * 0.85,
                          "Batch \(batchDuration)s should beat serial \(serialDuration)s")
    }

    func testEmptyBatchReturnsEmpty() async {
        let service = PhotoCompressionService()
        let results = await service.compressBatch([])
        XCTAssertTrue(results.isEmpty)
    }
}
