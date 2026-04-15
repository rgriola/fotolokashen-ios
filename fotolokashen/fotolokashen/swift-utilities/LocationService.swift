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
    private let geocodingService = GeocodingService.shared
    
    // MARK: - Geocoding (delegates to GeocodingService)
    
    /// Get address from coordinates
    func getAddress(latitude: Double, longitude: Double) async throws -> String {
        try await geocodingService.getAddress(latitude: latitude, longitude: longitude)
    }
    
    /// Get full geocoded address data from coordinates
    func getGeocodedAddress(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        try await geocodingService.getGeocodedAddress(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Create Location
    
    // REVIEW: createLocation() is missing caption, tags, personalRating, isFavorite, and color fields
    // that the web app supports at creation time. Users must edit the location post-create to add these.
    // Also: 40+ bare print statements below should be wrapped in #if DEBUG + enableDebugLogging checks
    // to match the project's debug logging pattern and avoid production performance impact.
    
    /// Create a new location with photo using geocoded address data
    func createLocation(
        name: String,
        type: String,
        latitude: Double,
        longitude: Double,
        geocodedAddress: GeocodedAddress,
        photo: UIImage,
        photoLocation: CLLocation?,
        productionDate: Date? = nil  // Optional production/filming date
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
            
            // Convert production date to ISO string if provided
            var productionDateString: String? = nil
            if let date = productionDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]  // YYYY-MM-DD only
                productionDateString = formatter.string(from: date)
                print("   productionDate: \(productionDateString ?? "nil")")
            }
            
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
                productionDate: productionDateString,
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

    // MARK: - Update Location

    /// Update a location via PATCH /api/locations/{locationId}
    /// Uses the Location ID (not UserSave ID). Handles both Location and UserSave fields.
    func updateLocation(locationId: Int, request: UpdateLocationRequest) async throws -> Location {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationService] Updating location ID: \(locationId)")
        }
        #endif

        isLoading = true
        defer { isLoading = false }

        do {
            let response: UpdateLocationResponse = try await apiClient.patch(
                "/api/locations/\(locationId)",
                body: request
            )

            var location = response.location
            // Carry UserSave fields onto the location
            if let userSave = response.userSave {
                location.userSaveId = userSave.id
                location.color = userSave.color
                location.isFavorite = userSave.isFavorite
                location.personalRating = userSave.personalRating
                location.caption = userSave.caption
                location.tags = userSave.tags
                location.visibility = userSave.visibility
            }

            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationService] Location updated successfully: \(location.name)")
            }
            #endif

            return location
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationService] Update location failed: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Delete Photo

    /// Delete a photo by its ID via DELETE /api/photos/{photoId}
    func deletePhoto(photoId: Int) async throws {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationService] Deleting photo ID: \(photoId)")
        }
        #endif

        do {
            let _: EmptyResponse = try await apiClient.delete("/api/photos/\(photoId)")

            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationService] Photo deleted successfully")
            }
            #endif
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationService] Delete photo failed: \(error)")
            }
            #endif
            throw error
        }
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
