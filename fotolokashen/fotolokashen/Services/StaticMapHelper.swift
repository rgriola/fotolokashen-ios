import Foundation

/// Helper for generating Google Maps Static API URLs
/// Used for location thumbnails when no photos are available
struct StaticMapHelper {
    
    /// Generate a static map URL for a given coordinate
    /// - Parameters:
    ///   - latitude: Location latitude
    ///   - longitude: Location longitude
    ///   - width: Image width in pixels (default: 300)
    ///   - height: Image height in pixels (default: 200)
    ///   - zoom: Map zoom level (default: 15)
    ///   - markerColor: Marker color (default: purple)
    /// - Returns: URL for the static map image
    static func staticMapURL(
        latitude: Double,
        longitude: Double,
        width: Int = 300,
        height: Int = 200,
        zoom: Int = 15,
        markerColor: String = "0x5B4CFF"
    ) -> URL? {
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        
        // Build static map URL
        // Docs: https://developers.google.com/maps/documentation/maps-static/start
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/staticmap")
        components?.queryItems = [
            URLQueryItem(name: "center", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "zoom", value: "\(zoom)"),
            URLQueryItem(name: "size", value: "\(width)x\(height)"),
            URLQueryItem(name: "markers", value: "color:\(markerColor)|size:mid|\(latitude),\(longitude)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "scale", value: "2") // Retina display
        ]
        
        return components?.url
    }
    
    /// Generate a static map URL optimized for location card thumbnails
    /// - Parameters:
    ///   - latitude: Location latitude
    ///   - longitude: Location longitude
    /// - Returns: URL for the static map image
    static func thumbnailMapURL(latitude: Double, longitude: Double) -> URL? {
        return staticMapURL(
            latitude: latitude,
            longitude: longitude,
            width: 400,
            height: 300,
            zoom: 15,
            markerColor: "0x5B4CFF" // Brand purple
        )
    }
}
