import Foundation
import CoreLocation
import Combine

/// Location manager for GPS tracking
@MainActor
class LocationManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    private let config = ConfigLoader.shared
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start tracking location
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            return
        }
        
        locationManager.startUpdatingLocation()
        
        if config.enableDebugLogging {
            print("[LocationManager] Started tracking location")
        }
    }
    
    /// Stop tracking location
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        
        if config.enableDebugLogging {
            print("[LocationManager] Stopped tracking location")
        }
    }
    
    /// Get current location once
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            return
        }
        
        locationManager.requestLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            self.location = location
            
            if config.enableDebugLogging {
                print("[LocationManager] Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                print("[LocationManager] Accuracy: \(location.horizontalAccuracy)m")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
            
            if config.enableDebugLogging {
                print("[LocationManager] Error: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            
            if config.enableDebugLogging {
                print("[LocationManager] Authorization status: \(authorizationStatus.rawValue)")
            }
            
            // Auto-start tracking if authorized
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                startTracking()
            }
        }
    }
}
