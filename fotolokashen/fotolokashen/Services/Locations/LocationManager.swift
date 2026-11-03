import CoreLocation
import Foundation
import Observation

/// Location manager for GPS tracking
@Observable
@MainActor
final class LocationManager: NSObject {
    
    // MARK: - Observable State
    
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Properties
    
    @ObservationIgnored private var locationManager: CLLocationManager?
    @ObservationIgnored private var shouldTrackLocation = false
    private let config = ConfigLoader.shared
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Request location permission
    func requestPermission() {
        locationManagerForUse().requestWhenInUseAuthorization()
    }
    
    /// Start tracking location
    func startTracking() {
        shouldTrackLocation = true
        let locationManager = locationManagerForUse()
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.startUpdatingLocation()
        
        if config.enableDebugLogging {
            dlog("LocationManager", "Started tracking location")
        }
    }
    
    /// Stop tracking location
    func stopTracking() {
        shouldTrackLocation = false
        locationManager?.stopUpdatingLocation()
        
        if config.enableDebugLogging {
            dlog("LocationManager", "Stopped tracking location")
        }
    }
    
    /// Get current location once
    func getCurrentLocation() {
        let locationManager = locationManagerForUse()
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationManager.requestLocation()
    }

    private func locationManagerForUse() -> CLLocationManager {
        if let locationManager {
            return locationManager
        }

        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        self.locationManager = locationManager
        authorizationStatus = locationManager.authorizationStatus
        return locationManager
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            self.location = location
            
            if config.enableDebugLogging {
                dlog("LocationManager", "Location updated")
                dlog("LocationManager", "Accuracy: \(location.horizontalAccuracy)m")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            
            if config.enableDebugLogging {
                dlog("LocationManager", "Location update failed")
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            
            if config.enableDebugLogging {
                dlog("LocationManager", "Authorization status: \(authorizationStatus.rawValue)")
            }
            
            // Auto-start tracking if authorized
            if shouldTrackLocation
                && (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
                startTracking()
            }
        }
    }
}
