import Foundation
import CoreLocation
import UIKit
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
        let locationType = location.type ?? ""
        self.markerIcon = MarkerIconGenerator.cameraMarker(for: locationType)
        super.init()
    }
}

/// Custom cluster item for social (friends'/public) locations with purple markers
class SocialLocationClusterItem: NSObject, GMUClusterItem {
    var position: CLLocationCoordinate2D
    var socialLocation: MapSocialLocation
    var markerIcon: UIImage

    init(socialLocation: MapSocialLocation) {
        self.socialLocation = socialLocation
        self.position = CLLocationCoordinate2D(
            latitude: socialLocation.latitude,
            longitude: socialLocation.longitude
        )
        self.markerIcon = MarkerIconGenerator.socialMarker()
        super.init()
    }
}

// MARK: - Custom Cluster Icon Generator (matches web app)

/// Generates cluster icons matching the web app design:
/// Camera icon + count number in a rounded rectangle with pin triangle.
class CameraClusterIconGenerator: NSObject, GMUClusterIconGenerator {
    func icon(forSize size: UInt) -> UIImage {
        MarkerIconGenerator.clusterIcon(count: Int(size))
    }
}

/// Custom cluster renderer that applies custom icons to location markers
class LocationClusterRenderer: GMUDefaultClusterRenderer {
    
    override init(mapView: GMSMapView, clusterIconGenerator iconGenerator: GMUClusterIconGenerator) {
        super.init(mapView: mapView, clusterIconGenerator: iconGenerator)
        self.delegate = self
    }
}

// MARK: - GMUClusterRendererDelegate
extension LocationClusterRenderer: GMUClusterRendererDelegate {
    
    /// Called before a marker is rendered - customize the icon
    func renderer(_ renderer: GMUClusterRenderer, willRenderMarker marker: GMSMarker) {
        if let clusterItem = marker.userData as? LocationClusterItem {
            // Apply the pre-generated custom camera icon
            marker.icon = clusterItem.markerIcon
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            marker.userData = clusterItem
        } else if let socialItem = marker.userData as? SocialLocationClusterItem {
            // Apply purple social marker icon
            marker.icon = socialItem.markerIcon
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            marker.userData = socialItem
        }
        // Cluster markers use the CameraClusterIconGenerator (camera + count)
        // and get anchored at the pin tip
        if !(marker.userData is LocationClusterItem) && !(marker.userData is SocialLocationClusterItem) {
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
        }
    }
}
