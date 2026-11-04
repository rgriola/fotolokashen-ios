import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import fotolokashen

nonisolated final class EXIFExtractorTests: XCTestCase {
    @MainActor
    func testExtractsGPSAndCameraMetadataFromImageData() throws {
        let data = try photoData(properties: [
            kCGImagePropertyOrientation as String: 6,
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 12.5,
                kCGImagePropertyGPSLatitudeRef as String: "S",
                kCGImagePropertyGPSLongitude as String: 45.25,
                kCGImagePropertyGPSLongitudeRef as String: "W",
                kCGImagePropertyGPSAltitude as String: 120.0
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Test Camera",
                kCGImagePropertyTIFFModel as String: "Model One"
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifISOSpeedRatings as String: [400],
                kCGImagePropertyExifFocalLength as String: 35.0,
                kCGImagePropertyExifFNumber as String: 2.8,
                kCGImagePropertyExifExposureTime as String: 0.008,
                kCGImagePropertyExifExposureMode as String: 1,
                kCGImagePropertyExifWhiteBalance as String: 1,
                kCGImagePropertyExifFlash as String: 1,
                kCGImagePropertyExifColorSpace as String: 1,
                kCGImagePropertyExifDateTimeOriginal as String: "2026:04:15 14:30:00"
            ]
        ])

        let metadata = try XCTUnwrap(EXIFExtractor.extract(from: data))

        XCTAssertEqual(try XCTUnwrap(metadata.latitude), -12.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(metadata.longitude), -45.25, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(metadata.altitude), 120, accuracy: 0.0001)
        XCTAssertEqual(metadata.cameraMake, "Test Camera")
        XCTAssertEqual(metadata.cameraModel, "Model One")
        XCTAssertEqual(metadata.iso, 400)
        XCTAssertEqual(metadata.focalLength, "35.0mm")
        XCTAssertEqual(metadata.aperture, "f/2.8")
        XCTAssertEqual(metadata.shutterSpeed, "1/125s")
        XCTAssertEqual(metadata.exposureMode, "Manual")
        XCTAssertEqual(metadata.whiteBalance, "Manual")
        XCTAssertEqual(metadata.flash, "Fired")
        XCTAssertEqual(metadata.colorSpace, "sRGB")
        XCTAssertEqual(metadata.orientation, 6)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        dateFormatter.timeZone = .current
        XCTAssertEqual(metadata.dateTaken, dateFormatter.date(from: "2026:04:15 14:30:00"))
    }

    @MainActor
    func testExtractsLongExposureAndPositiveGPS() throws {
        let data = try photoData(properties: [
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 8.5,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 10.25,
                kCGImagePropertyGPSLongitudeRef as String: "E"
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifISOSpeedRatings as String: [200],
                kCGImagePropertyExifFNumber as String: 4.0,
                kCGImagePropertyExifFocalLength as String: 50.0,
                kCGImagePropertyExifExposureTime as String: 2.0,
                kCGImagePropertyExifExposureMode as String: 2,
                kCGImagePropertyExifWhiteBalance as String: 0,
                kCGImagePropertyExifFlash as String: 0
            ]
        ])

        let metadata = try XCTUnwrap(EXIFExtractor.extract(from: data))

        XCTAssertEqual(try XCTUnwrap(metadata.latitude), 8.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(metadata.longitude), 10.25, accuracy: 0.0001)
        XCTAssertEqual(metadata.shutterSpeed, "2.0s")
        XCTAssertEqual(metadata.exposureMode, "Auto Bracket")
        XCTAssertEqual(metadata.whiteBalance, "Auto")
        XCTAssertEqual(metadata.flash, "No Flash")
    }

    func testInvalidImageDataReturnsNil() {
        XCTAssertNil(EXIFExtractor.extract(from: Data([0, 1, 2])))
    }

    @MainActor
    func testImageWithoutMetadataHasNoGPSOrExposureValues() throws {
        let data = try photoData(properties: [:])
        let metadata = try XCTUnwrap(EXIFExtractor.extract(from: data))

        XCTAssertNil(metadata.latitude)
        XCTAssertNil(metadata.longitude)
        XCTAssertNil(metadata.altitude)
        XCTAssertNil(metadata.iso)
        XCTAssertNil(metadata.shutterSpeed)
    }

    @MainActor
    private func photoData(properties: [String: Any]) throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
