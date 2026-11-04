import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import fotolokashen

nonisolated final class CameraSessionViewModelTests: XCTestCase {
    @MainActor
    func testPortraitFirstSessionPreservesEachPhotosOrientation() async throws {
        try await assertCaptureOrientations([.right, .up, .down, .right])
    }

    @MainActor
    func testLandscapeFirstSessionPreservesEachPhotosOrientation() async throws {
        try await assertCaptureOrientations([.up, .right, .down, .left])
    }

    @MainActor
    private func assertCaptureOrientations(_ orientations: [CGImagePropertyOrientation]) async throws {
        let session = CameraSessionViewModel()
        defer {
            for capture in session.sessionCaptures {
                session.removeCapture(capture)
            }
        }

        for (index, orientation) in orientations.enumerated() {
            let rawData = try photoData(orientation: orientation)
            let image = try XCTUnwrap(UIImage(data: rawData))
            let saved = expectation(description: "Capture \(index + 1) is saved")
            let waiter = ObservationWaiter(session, \.sessionCaptures, fulfilling: saved) {
                $0.count == index + 1
            }
            defer { waiter.cancel() }

            session.handleCapturedPhoto(image, rawData: rawData, location: nil)
            await fulfillment(of: [saved], timeout: 5)

            let capture = try XCTUnwrap(session.sessionCaptures.last)
            let savedData = try Data(contentsOf: capture.fileURL)
            XCTAssertEqual(savedData, rawData)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(savedData as CFData, nil))
            let properties = try XCTUnwrap(
                CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
            )
            XCTAssertEqual(
                (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value,
                orientation.rawValue
            )
            let fullImage = try XCTUnwrap(capture.loadFullImage())
            let pipelinePhoto = try XCTUnwrap(capture.toPipelinePhoto())
            XCTAssertEqual(fullImage.imageOrientation, image.imageOrientation)
            XCTAssertEqual(pipelinePhoto.originalImage.imageOrientation, image.imageOrientation)
            let expectedAspectRatio: CGFloat = orientation == .right || orientation == .left ? 0.5 : 2
            XCTAssertEqual(
                fullImage.size.width / fullImage.size.height,
                expectedAspectRatio,
                accuracy: 0.01
            )
            for maxDimension: CGFloat in [3000, 40] {
                let compressedData = try XCTUnwrap(ImageCompressor.compress(
                    pipelinePhoto.originalImage,
                    config: .init(maxDimension: maxDimension)
                ))
                let uploadedImage = try XCTUnwrap(UIImage(data: compressedData))
                XCTAssertEqual(
                    uploadedImage.size.width / uploadedImage.size.height,
                    expectedAspectRatio,
                    accuracy: 0.01
                )
            }
        }
    }

    @MainActor
    private func photoData(orientation: CGImagePropertyOrientation) throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
            UIColor.yellow.setFill()
            context.fill(CGRect(x: 40, y: 0, width: 40, height: 40))
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
