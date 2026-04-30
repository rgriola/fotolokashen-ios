import Foundation
import CoreLocation

// MARK: - GPS Spread Detection

/// Analyzes GPS spread across a set of photos and provides grouping recommendations.
/// Used by CreateLocationView to detect when photos span a large geographic area.
enum GPSSpreadAnalyzer {

    // MARK: - Configuration

    /// Distance threshold (in meters) above which the user is prompted to create a group.
    /// 500m ≈ 0.31 miles — reasonable for "same location" vs. "dispersed event".
    static let spreadThresholdMeters: Double = 500

    // MARK: - Analysis Result

    struct SpreadResult {
        /// Maximum distance (meters) between any two photos with GPS data
        let maxSpreadMeters: Double
        /// Number of photos that have GPS data
        let photosWithGPS: Int
        /// Total number of photos analyzed
        let totalPhotos: Int
        /// Geographic centroid of all GPS points
        let centroid: CLLocationCoordinate2D?
        /// All coordinates extracted (in original order)
        let coordinates: [CLLocationCoordinate2D]

        /// Whether the spread exceeds the threshold
        var exceedsThreshold: Bool {
            maxSpreadMeters > GPSSpreadAnalyzer.spreadThresholdMeters
        }

        /// Human-readable spread description
        var spreadDescription: String {
            if maxSpreadMeters < 1000 {
                return String(format: "%.0f meters", maxSpreadMeters)
            } else {
                let miles = maxSpreadMeters / 1609.344
                return String(format: "%.1f miles", miles)
            }
        }
    }

    // MARK: - Public API

    /// Analyze GPS spread across pipeline photos.
    /// Returns nil if no photos have GPS data.
    static func analyze(photos: [PipelinePhoto]) -> SpreadResult? {
        let coords = photos.compactMap { photo -> CLLocationCoordinate2D? in
            guard let gps = photo.gpsCoordinate else { return nil }
            return CLLocationCoordinate2D(latitude: gps.lat, longitude: gps.lng)
        }

        guard !coords.isEmpty else { return nil }

        // Calculate centroid
        let centroid = calculateCentroid(coords)

        // Calculate max spread (max distance between any pair)
        let maxSpread = calculateMaxSpread(coords)

        return SpreadResult(
            maxSpreadMeters: maxSpread,
            photosWithGPS: coords.count,
            totalPhotos: photos.count,
            centroid: centroid,
            coordinates: coords
        )
    }

    // MARK: - Haversine Distance

    /// Calculate the great-circle distance between two coordinates (in meters).
    static func haversineDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadiusMeters: Double = 6_371_000

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLng = (to.longitude - from.longitude) * .pi / 180

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    // MARK: - Private Helpers

    /// Calculate the maximum distance between any two points.
    private static func calculateMaxSpread(_ coords: [CLLocationCoordinate2D]) -> Double {
        guard coords.count >= 2 else { return 0 }

        var maxDistance: Double = 0
        for i in 0..<coords.count {
            for j in (i + 1)..<coords.count {
                let distance = haversineDistance(from: coords[i], to: coords[j])
                maxDistance = max(maxDistance, distance)
            }
        }
        return maxDistance
    }

    /// Calculate the geographic centroid of a set of coordinates.
    /// Uses mean of Cartesian coordinates projected back to lat/lng.
    private static func calculateCentroid(
        _ coords: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D {
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0

        for coord in coords {
            let lat = coord.latitude * .pi / 180
            let lng = coord.longitude * .pi / 180
            x += cos(lat) * cos(lng)
            y += cos(lat) * sin(lng)
            z += sin(lat)
        }

        let n = Double(coords.count)
        x /= n
        y /= n
        z /= n

        let lng = atan2(y, x) * 180 / .pi
        let hyp = sqrt(x * x + y * y)
        let lat = atan2(z, hyp) * 180 / .pi

        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
