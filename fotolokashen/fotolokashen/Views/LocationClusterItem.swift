import Foundation
import GoogleMaps
import GoogleMapsUtils

/// Custom cluster item for locations
class LocationClusterItem: NSObject, GMUClusterItem {
    var position: CLLocationCoordinate2D
    var location: Location
    
    init(location: Location) {
        self.location = location
        self.position = CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
        super.init()
    }
}

/// Custom cluster renderer with colored markers
class LocationClusterRenderer: GMUDefaultClusterRenderer {
    
    // Called to render individual location markers
    override func shouldRender(as cluster: GMUCluster, atZoom zoom: Float) -> Bool {
        // Use default clustering behavior
        return cluster.count > 1
    }
    
    // MARK: - Marker Icons
    
    func markerIcon(for type: String) -> UIImage {
        let color: UIColor
        
        switch type.uppercased() {
        case "BROLL":
            color = .systemBlue
        case "STORY":
            color = .systemPurple
        case "INTERVIEW":
            color = .systemOrange
        case "ESTABLISHING":
            color = .systemGreen
        case "DETAIL":
            color = .systemPink
        case "WIDE":
            color = .systemCyan
        case "MEDIUM":
            color = .systemIndigo
        case "CLOSE":
            color = .systemRed
        default:
            color = .systemGray
        }
        
        return GMSMarker.markerImage(with: color)
    }
}
