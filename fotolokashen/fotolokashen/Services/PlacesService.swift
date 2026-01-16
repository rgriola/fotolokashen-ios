import Foundation
import CoreLocation
import GooglePlaces

/// Service for interacting with Google Places API
class PlacesService {
    static let shared = PlacesService()
    private let placesClient: GMSPlacesClient
    private let config = ConfigLoader.shared
    
    private init() {
        placesClient = GMSPlacesClient.shared()
    }
    
    /// Reverse geocode coordinates to get Place ID and address
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> PlaceResult {
        if config.enableDebugLogging {
            print("[PlacesService] Reverse geocoding: \(coordinate.latitude), \(coordinate.longitude)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Use Places API to find nearby places
            let fields: GMSPlaceField = [.placeID, .name, .formattedAddress, .coordinate]
            
            placesClient.findPlaceLikelihoodsFromCurrentLocation(withPlaceFields: fields) { [weak self] (placeLikelihoods, error) in
                guard let self = self else {
                    continuation.resume(throwing: PlacesError.unknown)
                    return
                }
                
                if let error = error {
                    if self.config.enableDebugLogging {
                        print("[PlacesService] Error: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: PlacesError.apiError(error.localizedDescription))
                    return
                }
                
                guard let placeLikelihoods = placeLikelihoods, !placeLikelihoods.isEmpty else {
                    if self.config.enableDebugLogging {
                        print("[PlacesService] No places found")
                    }
                    continuation.resume(throwing: PlacesError.noPlacesFound)
                    return
                }
                
                // Get the most likely place
                if let place = placeLikelihoods.first?.place {
                    let result = PlaceResult(
                        placeId: place.placeID ?? "",
                        name: place.name ?? "",
                        address: place.formattedAddress ?? "",
                        coordinate: place.coordinate
                    )
                    
                    if self.config.enableDebugLogging {
                        print("[PlacesService] Found place: \(result.name)")
                        print("[PlacesService] Place ID: \(result.placeId)")
                        print("[PlacesService] Address: \(result.address)")
                    }
                    
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: PlacesError.noPlacesFound)
                }
            }
        }
    }
    
    /// Alternative method using geocoder for fallback
    func reverseGeocodeWithGeocoder(coordinate: CLLocationCoordinate2D) async throws -> PlaceResult {
        if config.enableDebugLogging {
            print("[PlacesService] Using CLGeocoder fallback")
        }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                guard let self = self else {
                    continuation.resume(throwing: PlacesError.unknown)
                    return
                }
                
                if let error = error {
                    if self.config.enableDebugLogging {
                        print("[PlacesService] Geocoder error: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: PlacesError.apiError(error.localizedDescription))
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: PlacesError.noPlacesFound)
                    return
                }
                
                // Build address from placemark
                var addressComponents: [String] = []
                if let street = placemark.thoroughfare { addressComponents.append(street) }
                if let city = placemark.locality { addressComponents.append(city) }
                if let state = placemark.administrativeArea { addressComponents.append(state) }
                if let zip = placemark.postalCode { addressComponents.append(zip) }
                
                let address = addressComponents.isEmpty ? 
                    "\(coordinate.latitude), \(coordinate.longitude)" : 
                    addressComponents.joined(separator: ", ")
                
                let result = PlaceResult(
                    placeId: "geocoded-\(Int(Date().timeIntervalSince1970))",
                    name: placemark.name ?? "Unknown Location",
                    address: address,
                    coordinate: coordinate
                )
                
                if self.config.enableDebugLogging {
                    print("[PlacesService] Geocoded address: \(result.address)")
                }
                
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Models

struct PlaceResult {
    let placeId: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

enum PlacesError: LocalizedError {
    case noPlacesFound
    case apiError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noPlacesFound:
            return "No places found at this location"
        case .apiError(let message):
            return "Places API error: \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
