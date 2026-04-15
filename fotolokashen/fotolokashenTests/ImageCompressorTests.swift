import XCTest
import UIKit
@testable import fotolokashen

final class ImageCompressorTests: XCTestCase {
    
    // MARK: - Test Image Creation
    
    func createTestImage(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Compression Tests
    
    func testCompressLargeImage() {
        // Given
        let largeImage = createTestImage(width: 4000, height: 3000)
        let maxSize: Int = 1_500_000 // 1.5MB
        let config = ImageCompressor.Config(targetBytes: maxSize)
        
        // When
        let result = ImageCompressor.compress(largeImage, config: config)
        
        // Then
        XCTAssertNotNil(result, "Compression should succeed")
        XCTAssertLessThanOrEqual(result!.count, maxSize, "Compressed data should be under max size")
    }
    
    func testCompressAlreadySmallImage() {
        // Given
        let smallImage = createTestImage(width: 800, height: 600)
        let maxSize: Int = 10_000_000 // 10MB
        let config = ImageCompressor.Config(targetBytes: maxSize)
        
        // When
        let result = ImageCompressor.compress(smallImage, config: config)
        
        // Then
        XCTAssertNotNil(result, "Compression should succeed")
        XCTAssertLessThanOrEqual(result!.count, maxSize, "Compressed data should be under max size")
    }
    
    func testCompressWithDifferentAspectRatios() {
        // Given
        let portraitImage = createTestImage(width: 3000, height: 4000)
        let landscapeImage = createTestImage(width: 4000, height: 3000)
        let squareImage = createTestImage(width: 3000, height: 3000)
        let maxSize: Int = 1_500_000
        let config = ImageCompressor.Config(targetBytes: maxSize)
        
        // When
        let portraitResult = ImageCompressor.compress(portraitImage, config: config)
        let landscapeResult = ImageCompressor.compress(landscapeImage, config: config)
        let squareResult = ImageCompressor.compress(squareImage, config: config)
        
        // Then
        XCTAssertNotNil(portraitResult, "Portrait compression should succeed")
        XCTAssertNotNil(landscapeResult, "Landscape compression should succeed")
        XCTAssertNotNil(squareResult, "Square compression should succeed")
        
        XCTAssertLessThanOrEqual(portraitResult!.count, maxSize)
        XCTAssertLessThanOrEqual(landscapeResult!.count, maxSize)
        XCTAssertLessThanOrEqual(squareResult!.count, maxSize)
    }
    
    func testCompressReturnsJPEGData() {
        // Given
        let image = createTestImage(width: 2000, height: 2000)
        
        // When
        let result = ImageCompressor.compress(image)
        
        // Then
        XCTAssertNotNil(result, "Compression should succeed")
        
        // Verify it's valid JPEG data by trying to create an image from it
        if let data = result {
            let recreatedImage = UIImage(data: data)
            XCTAssertNotNil(recreatedImage, "Should be able to create UIImage from compressed data")
        }
    }
    
    func testCompressWithVerySmallMaxSize() {
        // Given
        let image = createTestImage(width: 2000, height: 2000)
        let tinyMaxSize: Int = 10_000 // 10KB - very small
        let config = ImageCompressor.Config(targetBytes: tinyMaxSize)
        
        // When
        let result = ImageCompressor.compress(image, config: config)
        
        // Then
        XCTAssertNotNil(result, "Should still produce output even with tiny max size")
        // Note: May not always meet the size constraint with very small limits
    }
}
