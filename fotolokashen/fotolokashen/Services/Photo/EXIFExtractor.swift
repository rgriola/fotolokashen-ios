import Foundation
import UIKit
import ImageIO
import CoreLocation

/// Extracts EXIF metadata from image data using ImageIO (CGImageSource).
/// Reusable across apps — no fotolokashen-specific dependencies.
struct EXIFExtractor {

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

        // GPS
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
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

        // EXIF dictionary
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // ISO
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
               let iso = isoArray.first {
                metadata.iso = iso
            }

            // Focal length
            if let fl = exif[kCGImagePropertyExifFocalLength as String] as? Double {
                metadata.focalLength = String(format: "%.1fmm", fl)
            }

            // Aperture (FNumber)
            if let fNum = exif[kCGImagePropertyExifFNumber as String] as? Double {
                metadata.aperture = String(format: "f/%.1f", fNum)
            }

            // Shutter speed (ExposureTime)
            if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                if exposure >= 1.0 {
                    metadata.shutterSpeed = String(format: "%.1fs", exposure)
                } else {
                    let denominator = Int(round(1.0 / exposure))
                    metadata.shutterSpeed = "1/\(denominator)s"
                }
            }

            // Exposure mode
            if let mode = exif[kCGImagePropertyExifExposureMode as String] as? Int {
                switch mode {
                case 0: metadata.exposureMode = "Auto"
                case 1: metadata.exposureMode = "Manual"
                case 2: metadata.exposureMode = "Auto Bracket"
                default: metadata.exposureMode = "Unknown"
                }
            }

            // White balance
            if let wb = exif[kCGImagePropertyExifWhiteBalance as String] as? Int {
                metadata.whiteBalance = wb == 0 ? "Auto" : "Manual"
            }

            // Flash
            if let flash = exif[kCGImagePropertyExifFlash as String] as? Int {
                metadata.flash = (flash & 0x1) != 0 ? "Fired" : "No Flash"
            }

            // Color space
            if let cs = exif[kCGImagePropertyExifColorSpace as String] as? Int {
                switch cs {
                case 1: metadata.colorSpace = "sRGB"
                case 0xFFFF: metadata.colorSpace = "Uncalibrated"
                default: metadata.colorSpace = "Unknown"
                }
            }

            // Date taken
            if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                metadata.dateTaken = parseExifDate(dateStr)
            }
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
