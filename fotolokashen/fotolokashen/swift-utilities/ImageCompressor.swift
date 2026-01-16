import UIKit

/// Smart image compressor that reduces image size while maintaining quality
/// Implements a two-step process: resize then compress
struct ImageCompressor {
    
    // MARK: - Configuration
    
    struct Config {
        /// Target file size in bytes (default: 1.5MB)
        let targetBytes: Int
        
        /// Starting compression quality (0.0 - 1.0, default: 0.9)
        let qualityStart: CGFloat
        
        /// Minimum compression quality floor (0.0 - 1.0, default: 0.4)
        let qualityFloor: CGFloat
        
        /// Maximum dimension (width or height) in pixels (default: 3000)
        let maxDimension: CGFloat
        
        /// Quality reduction step per iteration (default: 0.1)
        let qualityStep: CGFloat
        
        /// Default configuration matching backend requirements
        static let `default` = Config(
            targetBytes: 1_500_000,      // 1.5MB
            qualityStart: 0.9,            // 90% quality
            qualityFloor: 0.4,            // Don't go below 40%
            maxDimension: 3000,           // Max 3000px
            qualityStep: 0.1              // Reduce by 10% each iteration
        )
        
        init(
            targetBytes: Int = 1_500_000,
            qualityStart: CGFloat = 0.9,
            qualityFloor: CGFloat = 0.4,
            maxDimension: CGFloat = 3000,
            qualityStep: CGFloat = 0.1
        ) {
            self.targetBytes = targetBytes
            self.qualityStart = qualityStart
            self.qualityFloor = qualityFloor
            self.maxDimension = maxDimension
            self.qualityStep = qualityStep
        }
    }
    
    // MARK: - Compression
    
    /// Compress an image to meet target size requirements
    /// - Parameters:
    ///   - image: The UIImage to compress
    ///   - config: Compression configuration (uses default if not provided)
    /// - Returns: Compressed JPEG data, or nil if compression failed
    static func compress(_ image: UIImage, config: Config = .default) -> Data? {
        // Step 1: Resize image if needed
        let resized = resize(image, maxDimension: config.maxDimension)
        
        // Step 2: Compress with iterative quality reduction
        var quality = config.qualityStart
        var imageData = resized.jpegData(compressionQuality: quality)
        
        // Keep reducing quality until we hit target size or quality floor
        while let data = imageData,
              data.count > config.targetBytes,
              quality > config.qualityFloor {
            quality -= config.qualityStep
            imageData = resized.jpegData(compressionQuality: quality)
        }
        
        return imageData
    }
    
    /// Compress an image and return metadata about the compression
    /// - Parameters:
    ///   - image: The UIImage to compress
    ///   - config: Compression configuration
    /// - Returns: Tuple containing compressed data and metadata
    static func compressWithMetadata(
        _ image: UIImage,
        config: Config = .default
    ) -> (data: Data?, metadata: CompressionMetadata)? {
        let originalSize = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        let resized = resize(image, maxDimension: config.maxDimension)
        
        var quality = config.qualityStart
        var imageData = resized.jpegData(compressionQuality: quality)
        var iterations = 0
        
        while let data = imageData,
              data.count > config.targetBytes,
              quality > config.qualityFloor {
            quality -= config.qualityStep
            imageData = resized.jpegData(compressionQuality: quality)
            iterations += 1
        }
        
        let metadata = CompressionMetadata(
            originalSize: originalSize,
            compressedSize: imageData?.count ?? 0,
            finalQuality: quality,
            iterations: iterations,
            wasResized: image.size.width > config.maxDimension || image.size.height > config.maxDimension
        )
        
        return (imageData, metadata)
    }
    
    // MARK: - Resizing
    
    /// Resize image to fit within maximum dimension while maintaining aspect ratio
    /// - Parameters:
    ///   - image: The UIImage to resize
    ///   - maxDimension: Maximum width or height IN PIXELS
    /// - Returns: Resized UIImage
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        // Get actual pixel size (not points)
        // UIImage.size returns points, multiply by scale to get pixels
        let scale = image.scale
        let pixelWidth = image.size.width * scale
        let pixelHeight = image.size.height * scale
        
        // If image is already smaller than max dimension, return original
        guard max(pixelWidth, pixelHeight) > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio (in pixels)
        let ratio = maxDimension / max(pixelWidth, pixelHeight)
        let newPixelWidth = pixelWidth * ratio
        let newPixelHeight = pixelHeight * ratio
        
        // Convert back to points for rendering
        let newSize = CGSize(
            width: newPixelWidth / scale,
            height: newPixelHeight / scale
        )
        
        // Use UIGraphicsImageRenderer for high-quality resizing
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale  // Maintain original scale
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Compression Metadata

struct CompressionMetadata {
    /// Original file size in bytes
    let originalSize: Int
    
    /// Compressed file size in bytes
    let compressedSize: Int
    
    /// Final compression quality used (0.0 - 1.0)
    let finalQuality: CGFloat
    
    /// Number of compression iterations performed
    let iterations: Int
    
    /// Whether the image was resized
    let wasResized: Bool
    
    /// Compression ratio (compressed / original)
    var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(compressedSize) / Double(originalSize)
    }
    
    /// Space saved in bytes
    var spaceSaved: Int {
        originalSize - compressedSize
    }
    
    /// Human-readable compression summary
    var summary: String {
        let ratio = String(format: "%.1f%%", compressionRatio * 100)
        let saved = ByteCountFormatter.string(fromByteCount: Int64(spaceSaved), countStyle: .file)
        return "Compressed to \(ratio) (saved \(saved))"
    }
}

// MARK: - Usage Example
/*
 // Basic usage
 let image = UIImage(named: "photo.jpg")!
 if let compressedData = ImageCompressor.compress(image) {
     print("Compressed size: \(compressedData.count) bytes")
 }
 
 // With custom configuration
 let config = ImageCompressor.Config(
     targetBytes: 2_000_000,  // 2MB
     qualityStart: 0.95,
     qualityFloor: 0.5,
     maxDimension: 4000
 )
 if let compressedData = ImageCompressor.compress(image, config: config) {
     print("Compressed size: \(compressedData.count) bytes")
 }
 
 // With metadata
 if let result = ImageCompressor.compressWithMetadata(image) {
     print(result.metadata.summary)
     print("Final quality: \(result.metadata.finalQuality)")
     print("Iterations: \(result.metadata.iterations)")
 }
 */
