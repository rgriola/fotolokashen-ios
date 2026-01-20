import Foundation
import GoogleMaps
import GoogleMapsUtils

/// Custom cluster item for locations with pre-generated marker icon
class LocationClusterItem: NSObject, GMUClusterItem {
    var position: CLLocationCoordinate2D
    var location: Location
    var markerIcon: UIImage
    
    init(location: Location) {
        self.location = location
        self.position = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        // Pre-generate the custom camera icon
        self.markerIcon = MarkerIconGenerator.cameraMarker(for: location.type ?? "")
        super.init()
    }
}

/// Custom cluster renderer that applies custom icons to location markers
class LocationClusterRenderer: GMUDefaultClusterRenderer {
    
    override init(mapView: GMSMapView, clusterIconGenerator iconGenerator: GMUClusterIconGenerator) {
        super.init(mapView: mapView, clusterIconGenerator: iconGenerator)
        // Set self as delegate to customize markers
        self.delegate = self
    }
}

// MARK: - GMUClusterRendererDelegate
extension LocationClusterRenderer: GMUClusterRendererDelegate {
    
    /// Called before a marker is rendered - this is where we customize the icon
    func renderer(_ renderer: GMUClusterRenderer, willRenderMarker marker: GMSMarker) {
        // Check if this marker represents a single location item (not a cluster)
        if let clusterItem = marker.userData as? LocationClusterItem {
            // Apply the pre-generated custom camera icon
            marker.icon = clusterItem.markerIcon
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            // Store the location for tap handling
            marker.userData = clusterItem
            print("[LocationClusterRenderer] Applied custom icon for: \(clusterItem.location.name)")
        }
        // Cluster markers keep their default appearance (colored circles)
    }
}
