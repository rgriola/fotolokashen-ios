import Foundation
import CoreLocation

/// Service for reverse geocoding coordinates to addresses
class PlacesService {
    static let shared = PlacesService()
    private let config = ConfigLoader.shared
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    /// Reverse geocode coordinates to get address and place info
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> PlaceResult {
        if config.enableDebugLogging {
            print("[PlacesService] Reverse geocoding: \(coordinate.latitude), \(coordinate.longitude)")
        }
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                if config.enableDebugLogging {
                    print("[PlacesService] No placemarks found")
                }
                throw PlacesError.noPlacesFound
            }
            
            // Build formatted address
            var addressComponents: [String] = []
            
            if let subThoroughfare = placemark.subThoroughfare {
                addressComponents.append(subThoroughfare)
            }
            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            if let locality = placemark.locality {
                addressComponents.append(locality)
            }
            if let administrativeArea = placemark.administrativeArea {
                addressComponents.append(administrativeArea)
            }
            if let postalCode = placemark.postalCode {
                addressComponents.append(postalCode)
            }
            if let country = placemark.country {
                addressComponents.append(country)
            }
            
            let formattedAddress = addressComponents.isEmpty ? 
                "\(coordinate.latitude), \(coordinate.longitude)" : 
                addressComponents.joined(separator: ", ")
            
            // Generate a place ID (for now, use timestamp-based ID)
            // TODO: Integrate Google Places API for real Place IDs
            let placeId = "place-\(Int(Date().timeIntervalSince1970))"
            
            // Use name or build from address components
            let name = placemark.name ?? 
                       placemark.thoroughfare ?? 
                       placemark.locality ?? 
                       "Unknown Location"
            
            let result = PlaceResult(
                placeId: placeId,
                name: name,
                address: formattedAddress,
                coordinate: coordinate,
                locality: placemark.locality,
                administrativeArea: placemark.administrativeArea,
                country: placemark.country
            )
            
            if config.enableDebugLogging {
                print("[PlacesService] ✅ Geocoded successfully")
                print("[PlacesService] Name: \(result.name)")
                print("[PlacesService] Address: \(result.address)")
                print("[PlacesService] Place ID: \(result.placeId)")
            }
            
            return result
            
        } catch {
            if config.enableDebugLogging {
                print("[PlacesService] ❌ Geocoding failed: \(error.localizedDescription)")
            }
            throw PlacesError.apiError(error.localizedDescription)
        }
    }
}

// MARK: - Models

struct PlaceResult {
    let placeId: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let locality: String?
    let administrativeArea: String?
    let country: String?
}

enum PlacesError: LocalizedError {
    case noPlacesFound
    case apiError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noPlacesFound:
            return "No address found for this location"
        case .apiError(let message):
            return "Geocoding error: \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
