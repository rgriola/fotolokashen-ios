import Foundation
import CoreLocation
import UIKit
import Combine

/// Service for managing locations (CRUD operations)
@MainActor
class LocationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let apiClient = APIClient.shared
    private let photoUploadService = PhotoUploadService()
    private let config = ConfigLoader.shared
    
    // MARK: - Create Location
    
    /// Create a new location with photo
    func createLocation(
        name: String,
        type: String,
        latitude: Double,
        longitude: Double,
        address: String,
        photo: UIImage,
        photoLocation: CLLocation?
    ) async throws -> Location {
        isLoading = true
        errorMessage = nil
        
        do {
            if config.enableDebugLogging {
                print("[LocationService] Creating location: \(name)")
            }
            
            // Step 1: Create location
            let createRequest = CreateLocationRequest(
                placeId: "photo-\(Date().timeIntervalSince1970)",
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude,
                type: type.lowercased(),
                notes: nil,
                rating: nil
            )
            
            let response: CreateLocationResponse = try await apiClient.post(
                "/api/locations",
                body: createRequest
            )
            
            let location = response.userSave.location
            
            if config.enableDebugLogging {
                print("[LocationService] Location created with ID: \(location.id)")
            }
            
            // Step 2: Upload photo to the location
            do {
                let uploadedPhoto = try await photoUploadService.uploadPhoto(
                    image: photo,
                    locationId: location.id,
                    location: photoLocation,
                    caption: nil
                )
                
                if config.enableDebugLogging {
                    print("[LocationService] Photo uploaded with ID: \(uploadedPhoto.id)")
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
    
    // MARK: - Geocoding
    
    /// Get address from coordinates using Google Maps Geocoding API
    func getAddress(latitude: Double, longitude: Double) async throws -> String {
        let apiKey = config.googleMapsAPIKey
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(latitude),\(longitude)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw LocationServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LocationServiceError.geocodingFailed
        }
        
        let geocodeResponse = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        
        guard let firstResult = geocodeResponse.results.first else {
            throw LocationServiceError.noResults
        }
        
        return firstResult.formattedAddress
    }
}

// MARK: - Geocoding Response

struct GeocodeResponse: Codable {
    let results: [GeocodeResult]
    let status: String
}

struct GeocodeResult: Codable {
    let formattedAddress: String
    
    enum CodingKeys: String, CodingKey {
        case formattedAddress = "formatted_address"
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
