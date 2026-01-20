import Foundation
import CoreLocation
import UIKit
import Combine

/// Service for managing locations (CRUD operations)
@MainActor
class LocationService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LocationService()
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let apiClient = APIClient.shared
    private let photoUploadService = PhotoUploadService()
    private let config = ConfigLoader.shared
    
    // MARK: - Create Location
    
    /// Create a new location with photo using geocoded address data
    func createLocation(
        name: String,
        type: String,
        latitude: Double,
        longitude: Double,
        geocodedAddress: GeocodedAddress,
        photo: UIImage,
        photoLocation: CLLocation?
    ) async throws -> Location {
        isLoading = true
        errorMessage = nil
        
        do {
            print("💾 [LocationService.createLocation] ========== START ==========")
            print("💾 [LocationService.createLocation] Input parameters:")
            print("   name: \(name)")
            print("   type: \(type)")
            print("   latitude: \(latitude)")
            print("   longitude: \(longitude)")
            print("💾 [LocationService.createLocation] GeocodedAddress data:")
            print("   placeId: \(geocodedAddress.placeId)")
            print("   formattedAddress: \(geocodedAddress.formattedAddress)")
            print("   fullStreet: \(geocodedAddress.fullStreet ?? "nil")")
            print("   city: \(geocodedAddress.city ?? "nil")")
            print("   state: \(geocodedAddress.state ?? "nil")")
            print("   zipcode: \(geocodedAddress.zipcode ?? "nil")")
            
            // Step 1: Create location with full address data
            let createRequest = CreateLocationRequest(
                placeId: geocodedAddress.placeId,
                name: name,
                address: geocodedAddress.formattedAddress,
                latitude: latitude,
                longitude: longitude,
                type: type,  // Keep original case (uppercase) to match web app
                notes: nil,
                rating: nil,
                street: geocodedAddress.fullStreet,
                city: geocodedAddress.city,
                state: geocodedAddress.state,
                zipcode: geocodedAddress.zipcode
            )
            
            print("💾 [LocationService.createLocation] CreateLocationRequest built:")
            print("   placeId: \(createRequest.placeId)")
            print("   name: \(createRequest.name)")
            print("   address: \(createRequest.address)")
            print("   latitude: \(createRequest.latitude)")
            print("   longitude: \(createRequest.longitude)")
            print("   type: \(createRequest.type ?? "nil")")
            print("   street: \(createRequest.street ?? "nil")")
            print("   city: \(createRequest.city ?? "nil")")
            print("   state: \(createRequest.state ?? "nil")")
            print("   zipcode: \(createRequest.zipcode ?? "nil")")
            
            print("💾 [LocationService.createLocation] Sending POST to /api/locations...")
            
            let response: CreateLocationResponse = try await apiClient.post(
                "/api/locations",
                body: createRequest
            )
            
            var location = response.userSave.location
            let userSaveId = response.userSave.id  // Store UserSave ID for fetching later
            location.userSaveId = userSaveId  // Set userSaveId for delete operations
            
            print("✅ [LocationService.createLocation] Location created successfully!")
            print("   Location ID: \(location.id)")
            print("   UserSave ID: \(userSaveId)")
            print("   Returned address: \(location.address ?? "nil")")
            
            // Step 2: Upload photo to the location
            do {
                print("📷 [LocationService.createLocation] Uploading photo...")
                let uploadedPhoto = try await photoUploadService.uploadPhoto(
                    image: photo,
                    locationId: location.id,
                    location: photoLocation,
                    caption: nil
                )
                
                if config.enableDebugLogging {
                    print("[LocationService] Photo uploaded with ID: \(uploadedPhoto.id)")
                }
                
                // Step 3: Fetch the updated location using UserSave ID to get the photo data
                var updatedLocation = try await fetchLocation(userSaveId: userSaveId)
                updatedLocation.userSaveId = userSaveId  // Preserve userSaveId
                location = updatedLocation
                
                if config.enableDebugLogging {
                    print("[LocationService] Fetched updated location with \(location.photos?.count ?? 0) photos")
                }
            } catch {
                // Photo upload failed, but location was created
                if config.enableDebugLogging {
                    print("[LocationService] Photo upload failed: \(error)")
                }
                // Continue anyway - location exists
            }
            
            isLoading = false
            return location
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            
            if config.enableDebugLogging {
                print("[LocationService] Create location failed: \(error)")
            }
            
            throw error
        }
    }
    
    // MARK: - Fetch Locations
    
    /// Fetch a single location by UserSave ID
    func fetchLocation(userSaveId: Int) async throws -> Location {
        if config.enableDebugLogging {
            print("[LocationService] Fetching location with UserSave ID: \(userSaveId)")
        }
        
        do {
            let response: UserSaveDetailResponse = try await apiClient.get("/api/locations/\(userSaveId)")
            
            if config.enableDebugLogging {
                print("[LocationService] Fetched location: \(response.userSave.location.name)")
            }
            
            return response.userSave.location
        } catch {
            if config.enableDebugLogging {
                print("[LocationService] Fetch location failed: \(error)")
            }
            throw error
        }
    }
    
    /// Fetch all locations for the current user
    func fetchLocations() async throws -> [Location] {
        if config.enableDebugLogging {
            print("[LocationService] Fetching locations...")
        }
        
        do {
            let response: LocationsResponse = try await apiClient.get("/api/locations")
            
            // Unwrap locations from UserSave objects
            let locations = response.unwrappedLocations
            
            if config.enableDebugLogging {
                print("[LocationService] Fetched \(locations.count) locations")
            }
            
            return locations
        } catch {
            if config.enableDebugLogging {
                print("[LocationService] Fetch locations failed: \(error)")
            }
            throw error
        }
    }
    
    // MARK: - Delete Location
    
    /// Delete a location by UserSave ID
    func deleteLocation(userSaveId: Int) async throws {
        if config.enableDebugLogging {
            print("[LocationService] Deleting location with UserSave ID: \(userSaveId)")
        }
        
        do {
            let _: EmptyResponse = try await apiClient.delete("/api/locations/\(userSaveId)")
            
            if config.enableDebugLogging {
                print("[LocationService] Location deleted successfully")
            }
        } catch {
            if config.enableDebugLogging {
                print("[LocationService] Delete location failed: \(error)")
            }
            throw error
        }
    }
    
    // MARK: - Geocoding
    
    /// Get address from coordinates using Google Maps Geocoding API
    /// Returns just the formatted address string (legacy method)
    func getAddress(latitude: Double, longitude: Double) async throws -> String {
        print("📍 [LocationService.getAddress] Called with lat: \(latitude), lng: \(longitude)")
        let geocodedAddress = try await getGeocodedAddress(latitude: latitude, longitude: longitude)
        print("📍 [LocationService.getAddress] Returning: \(geocodedAddress.formattedAddress)")
        return geocodedAddress.formattedAddress
    }
    
    /// Get full geocoded address data from coordinates
    /// Tries Google Maps Geocoding API first, falls back to Apple CLGeocoder
    func getGeocodedAddress(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        print("🌍 [LocationService.getGeocodedAddress] ========== START ==========")
        print("🌍 [LocationService.getGeocodedAddress] Input coordinates: \(latitude), \(longitude)")
        
        // Try Google Maps first
        do {
            let result = try await getGeocodedAddressFromGoogle(latitude: latitude, longitude: longitude)
            print("✅ [LocationService.getGeocodedAddress] Google Maps geocoding succeeded")
            return result
        } catch {
            print("⚠️ [LocationService.getGeocodedAddress] Google Maps failed: \(error)")
            print("🍎 [LocationService.getGeocodedAddress] Falling back to Apple CLGeocoder...")
        }
        
        // Fallback to Apple's CLGeocoder (no API key needed)
        return try await getGeocodedAddressFromApple(latitude: latitude, longitude: longitude)
    }
    
    /// Geocode using Google Maps API
    private func getGeocodedAddressFromGoogle(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        print("🌍 [Google Geocoding] Starting...")
        
        let apiKey = config.googleMapsAPIKey
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(latitude),\(longitude)&key=\(apiKey)"
        
        print("🌍 [Google Geocoding] API URL: \(urlString.replacingOccurrences(of: apiKey, with: "***API_KEY***"))")
        
        guard let url = URL(string: urlString) else {
            print("❌ [Google Geocoding] Invalid URL!")
            throw LocationServiceError.invalidURL
        }
        
        print("🌍 [Google Geocoding] Making API request...")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [Google Geocoding] Invalid HTTP response")
            throw LocationServiceError.geocodingFailed
        }
        
        print("🌍 [Google Geocoding] HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [Google Geocoding] Bad status code: \(httpResponse.statusCode)")
            throw LocationServiceError.geocodingFailed
        }
        
        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🌍 [Google Geocoding] Raw JSON response (first 1000 chars):")
            print(String(jsonString.prefix(1000)))
        }
        
        let geocodeResponse: GeocodeResponse
        do {
            geocodeResponse = try JSONDecoder().decode(GeocodeResponse.self, from: data)
            print("🌍 [Google Geocoding] JSON decoded successfully")
            print("🌍 [Google Geocoding] Status: \(geocodeResponse.status)")
            print("🌍 [Google Geocoding] Results count: \(geocodeResponse.results.count)")
        } catch {
            print("❌ [Google Geocoding] JSON decode error: \(error)")
            throw error
        }
        
        // Check for API errors
        if geocodeResponse.status != "OK" {
            print("❌ [Google Geocoding] API returned status: \(geocodeResponse.status)")
            throw LocationServiceError.geocodingFailed
        }
        
        guard let firstResult = geocodeResponse.results.first else {
            print("❌ [Google Geocoding] No results in response!")
            throw LocationServiceError.noResults
        }
        
        print("🌍 [Google Geocoding] First result:")
        print("   - placeId: \(firstResult.placeId)")
        print("   - formattedAddress: \(firstResult.formattedAddress)")
        print("   - addressComponents count: \(firstResult.addressComponents.count)")
        
        // Extract address components
        var streetNumber: String?
        var street: String?
        var city: String?
        var state: String?
        var zipcode: String?
        
        print("🌍 [Google Geocoding] Parsing address components:")
        for component in firstResult.addressComponents {
            let types = component.types
            print("   - Component: '\(component.longName)' types: \(types)")
            
            if types.contains("street_number") {
                streetNumber = component.longName
                print("     → Matched as STREET_NUMBER")
            } else if types.contains("route") {
                street = component.longName
                print("     → Matched as ROUTE (street)")
            } else if types.contains("locality") {
                city = component.longName
                print("     → Matched as LOCALITY (city)")
            } else if types.contains("administrative_area_level_1") {
                state = component.shortName
                print("     → Matched as STATE: \(component.shortName)")
            } else if types.contains("postal_code") {
                zipcode = component.longName
                print("     → Matched as POSTAL_CODE")
            }
        }
        
        let geocodedAddress = GeocodedAddress(
            placeId: firstResult.placeId,
            formattedAddress: firstResult.formattedAddress,
            streetNumber: streetNumber,
            street: street,
            city: city,
            state: state,
            zipcode: zipcode
        )
        
        print("🌍 [Google Geocoding] ========== RESULT ==========")
        print("   placeId: \(geocodedAddress.placeId)")
        print("   formattedAddress: \(geocodedAddress.formattedAddress)")
        print("   streetNumber: \(geocodedAddress.streetNumber ?? "nil")")
        print("   street: \(geocodedAddress.street ?? "nil")")
        print("   fullStreet: \(geocodedAddress.fullStreet ?? "nil")")
        print("   city: \(geocodedAddress.city ?? "nil")")
        print("   state: \(geocodedAddress.state ?? "nil")")
        print("   zipcode: \(geocodedAddress.zipcode ?? "nil")")
        print("🌍 [Google Geocoding] ========== END ==========")
        
        return geocodedAddress
    }
    
    /// Geocode using Apple's CLGeocoder (no API key needed)
    private func getGeocodedAddressFromApple(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        print("🍎 [Apple Geocoding] Starting...")
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.reverseGeocodeLocation(location)
            print("🍎 [Apple Geocoding] Got \(placemarks.count) placemark(s)")
        } catch {
            print("❌ [Apple Geocoding] Failed: \(error)")
            throw LocationServiceError.geocodingFailed
        }
        
        guard let placemark = placemarks.first else {
            print("❌ [Apple Geocoding] No placemarks returned")
            throw LocationServiceError.noResults
        }
        
        print("🍎 [Apple Geocoding] Placemark data:")
        print("   - name: \(placemark.name ?? "nil")")
        print("   - thoroughfare: \(placemark.thoroughfare ?? "nil")")
        print("   - subThoroughfare: \(placemark.subThoroughfare ?? "nil")")
        print("   - locality: \(placemark.locality ?? "nil")")
        print("   - administrativeArea: \(placemark.administrativeArea ?? "nil")")
        print("   - postalCode: \(placemark.postalCode ?? "nil")")
        
        // Build formatted address
        var addressParts: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            addressParts.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            addressParts.append(thoroughfare)
        } else if let name = placemark.name {
            addressParts.append(name)
        }
        
        if let city = placemark.locality {
            addressParts.append(city)
        }
        
        if let state = placemark.administrativeArea {
            addressParts.append(state)
        }
        
        if let zipcode = placemark.postalCode {
            addressParts.append(zipcode)
        }
        
        let formattedAddress = addressParts.joined(separator: ", ")
        
        // Generate a unique placeId since Apple doesn't provide Google Place IDs
        // Use "apple-" prefix to distinguish from Google Place IDs
        let applePlaceId = "apple-\(latitude)-\(longitude)-\(Date().timeIntervalSince1970)"
        
        let geocodedAddress = GeocodedAddress(
            placeId: applePlaceId,
            formattedAddress: formattedAddress,
            streetNumber: placemark.subThoroughfare,
            street: placemark.thoroughfare,
            city: placemark.locality,
            state: placemark.administrativeArea,
            zipcode: placemark.postalCode
        )
        
        print("🍎 [Apple Geocoding] ========== RESULT ==========")
        print("   placeId: \(geocodedAddress.placeId)")
        print("   formattedAddress: \(geocodedAddress.formattedAddress)")
        print("   streetNumber: \(geocodedAddress.streetNumber ?? "nil")")
        print("   street: \(geocodedAddress.street ?? "nil")")
        print("   fullStreet: \(geocodedAddress.fullStreet ?? "nil")")
        print("   city: \(geocodedAddress.city ?? "nil")")
        print("   state: \(geocodedAddress.state ?? "nil")")
        print("   zipcode: \(geocodedAddress.zipcode ?? "nil")")
        print("🍎 [Apple Geocoding] ========== END ==========")
        
        return geocodedAddress
    }
}

// MARK: - Geocoding Response

struct GeocodeResponse: Codable {
    let results: [GeocodeResult]
    let status: String
}

struct GeocodeResult: Codable {
    let placeId: String
    let formattedAddress: String
    let addressComponents: [AddressComponent]
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case formattedAddress = "formatted_address"
        case addressComponents = "address_components"
    }
}

struct AddressComponent: Codable {
    let longName: String
    let shortName: String
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case shortName = "short_name"
        case types
    }
}

/// Structured geocoding data extracted from Google Geocoding API
struct GeocodedAddress {
    let placeId: String
    let formattedAddress: String
    let streetNumber: String?
    let street: String?
    let city: String?
    let state: String?
    let zipcode: String?
    
    /// Combines street number and street name into a full street address
    var fullStreet: String? {
        if let number = streetNumber, let route = street {
            return "\(number) \(route)"
        }
        return street
    }
}

// MARK: - Errors

enum LocationServiceError: Error, LocalizedError {
    case invalidURL
    case geocodingFailed
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid geocoding URL"
        case .geocodingFailed:
            return "Failed to get address from coordinates"
        case .noResults:
            return "No address found for these coordinates"
        }
    }
}
