import CoreLocation
import Foundation
import ImageIO
import UIKit

/// Extracts EXIF metadata from image data using ImageIO (CGImageSource).
/// Reusable across apps — no fotolokashen-specific dependencies.
nonisolated struct EXIFExtractor {

    // MARK: - Public API

    /// Extract EXIF metadata from raw image data (JPEG, HEIC, TIFF, PNG).
    /// Returns nil if the data cannot be parsed as an image.
    static func extract(from data: Data) -> EXIFMetadata? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        var metadata = EXIFMetadata()

        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            extractGPS(from: gps, into: &metadata)
        }

        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            extractExposure(from: exif, into: &metadata)
            extractCameraSettings(from: exif, into: &metadata)
        }

        // TIFF dictionary (camera make/model)
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            metadata.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            metadata.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        }

        // Lens info (from EXIF Aux dictionary)
        if let exifAux = properties[kCGImagePropertyExifAuxDictionary as String] as? [String: Any] {
            metadata.lensMake = exifAux["LensMake"] as? String
            metadata.lensModel = exifAux["LensModel"] as? String
        }
        // Lens info fallback (from main EXIF dictionary)
        if metadata.lensModel == nil,
           let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            metadata.lensModel = exif["LensModel"] as? String
            metadata.lensMake = exif["LensMake"] as? String
        }

        // Orientation
        if let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
            metadata.orientation = orientation
        }

        return metadata
    }

    /// Extract EXIF from a UIImage by converting to JPEG data first.
    /// Note: UIImage may lose some EXIF — prefer using raw Data when available.
    static func extract(from image: UIImage) -> EXIFMetadata? {
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        return extract(from: data)
    }

    // MARK: - Private Helpers

    private static func extractGPS(from gps: [String: Any], into metadata: inout EXIFMetadata) {
        metadata.latitude = gpsCoordinate(
            from: gps,
            valueKey: kCGImagePropertyGPSLatitude as String,
            refKey: kCGImagePropertyGPSLatitudeRef as String,
            negativeRef: "S"
        )
        metadata.longitude = gpsCoordinate(
            from: gps,
            valueKey: kCGImagePropertyGPSLongitude as String,
            refKey: kCGImagePropertyGPSLongitudeRef as String,
            negativeRef: "W"
        )
        metadata.altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double
    }

    private static func extractExposure(from exif: [String: Any], into metadata: inout EXIFMetadata) {
        if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
           let iso = isoArray.first {
            metadata.iso = iso
        }
        if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            metadata.focalLength = String(format: "%.1fmm", focalLength)
        }
        if let aperture = exif[kCGImagePropertyExifFNumber as String] as? Double {
            metadata.aperture = String(format: "f/%.1f", aperture)
        }
        if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? Double {
            if exposure >= 1.0 {
                metadata.shutterSpeed = String(format: "%.1fs", exposure)
            } else {
                let denominator = Int(round(1.0 / exposure))
                metadata.shutterSpeed = "1/\(denominator)s"
            }
        }
    }

    private static func extractCameraSettings(from exif: [String: Any], into metadata: inout EXIFMetadata) {
        if let mode = exif[kCGImagePropertyExifExposureMode as String] as? Int {
            metadata.exposureMode = exposureMode(for: mode)
        }
        if let whiteBalance = exif[kCGImagePropertyExifWhiteBalance as String] as? Int {
            metadata.whiteBalance = whiteBalance == 0 ? "Auto" : "Manual"
        }
        if let flash = exif[kCGImagePropertyExifFlash as String] as? Int {
            metadata.flash = (flash & 0x1) != 0 ? "Fired" : "No Flash"
        }
        if let colorSpace = exif[kCGImagePropertyExifColorSpace as String] as? Int {
            switch colorSpace {
            case 1: metadata.colorSpace = "sRGB"
            case 0xFFFF: metadata.colorSpace = "Uncalibrated"
            default: metadata.colorSpace = "Unknown"
            }
        }
        if let date = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            metadata.dateTaken = parseExifDate(date)
        }
    }

    private static func exposureMode(for mode: Int) -> String {
        switch mode {
        case 0: return "Auto"
        case 1: return "Manual"
        case 2: return "Auto Bracket"
        default: return "Unknown"
        }
    }

    /// Parse GPS coordinate from EXIF GPS dictionary, applying N/S or E/W reference.
    private static func gpsCoordinate(
        from gps: [String: Any],
        valueKey: String,
        refKey: String,
        negativeRef: String
    ) -> Double? {
        guard let value = gps[valueKey] as? Double else { return nil }
        let ref = gps[refKey] as? String ?? ""
        return ref == negativeRef ? -value : value
    }

    /// Parse EXIF date string (format: "2026:04:15 14:30:00") to Date.
    private static func parseExifDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)
    }
}
