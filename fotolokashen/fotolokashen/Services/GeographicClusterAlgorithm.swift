import Foundation
import CoreLocation
import GoogleMaps
import GoogleMapsUtils

/// Custom clustering algorithm that groups markers by geographic proximity
/// and calculates cluster positions at the centroid of grouped markers.
/// 
/// This prevents clusters from appearing at grid positions (which can be in the ocean)
/// and ensures clusters only form when markers are within reasonable distance.
class GeographicClusterAlgorithm: NSObject, GMUClusterAlgorithm {
    
    // Maximum distance in miles for markers to be clustered together
    private let maxClusterDistanceMiles: Double
    
    // Stored items to cluster
    private var items: [GMUClusterItem] = []
    
    init(maxDistanceMiles: Double = 50.0) {
        self.maxClusterDistanceMiles = maxDistanceMiles
        super.init()
    }
    
    func add(_ items: [GMUClusterItem]) {
        self.items.append(contentsOf: items)
    }
    
    func remove(_ item: GMUClusterItem) {
        self.items.removeAll { $0 === item }
    }
    
    func clearItems() {
        self.items.removeAll()
    }
    
    func clusters(atZoom zoom: Float) -> [GMUCluster] {
        // Zoom level threshold for clustering
        let minZoomForClustering: Float = 3.0
        
        // If zoomed out too far or no items, return individual clusters
        if zoom < minZoomForClustering || items.isEmpty {
            return items.map { StaticCluster(items: [$0]) }
        }
        
        // Adjust clustering distance based on zoom level
        // Higher zoom = tighter clustering (smaller radius)
        let zoomFactor = max(1.0, (15.0 - Double(zoom)) / 10.0) // 15 is a typical "street-level" zoom
        let effectiveDistance = maxClusterDistanceMiles * zoomFactor
        
        // Group items by geographic proximity
        var clusters: [StaticCluster] = []
        var processed = Set<Int>()
        
        for (index, item) in items.enumerated() {
            guard !processed.contains(index) else { continue }
            
            // Start a new cluster with this item
            var clusterItems: [GMUClusterItem] = [item]
            processed.insert(index)
            
            // Find nearby items to add to this cluster
            for (otherIndex, otherItem) in items.enumerated() {
                guard !processed.contains(otherIndex) else { continue }
                
                // Check if this item is close enough to any item in the current cluster
                let isNearby = clusterItems.contains { clusterItem in
                    let distance = calculateDistance(
                        from: clusterItem.position,
                        to: otherItem.position
                    )
                    return distance <= effectiveDistance
                }
                
                if isNearby {
                    clusterItems.append(otherItem)
                    processed.insert(otherIndex)
                }
            }
            
            // Create cluster with these items
            clusters.append(StaticCluster(items: clusterItems))
        }
        
        return clusters
    }
    
    /// Calculate geographic distance between two coordinates in miles
    private func calculateDistance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location2.distance(from: location1) / 1609.34 // Convert meters to miles
    }
}

/// Simple cluster implementation that calculates centroid position
class StaticCluster: NSObject, GMUCluster {
    private let _items: [GMUClusterItem]
    private let _position: CLLocationCoordinate2D
    
    var items: [GMUClusterItem] {
        return _items
    }
    
    var position: CLLocationCoordinate2D {
        return _position
    }
    
    var count: UInt {
        return UInt(_items.count)
    }
    
    init(items: [GMUClusterItem]) {
        self._items = items
        
        // Calculate centroid position as average of all item positions
        if items.isEmpty {
            self._position = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        } else {
            let avgLat = items.reduce(0.0) { $0 + $1.position.latitude } / Double(items.count)
            let avgLng = items.reduce(0.0) { $0 + $1.position.longitude } / Double(items.count)
            self._position = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng)
        }
        
        super.init()
    }
}
