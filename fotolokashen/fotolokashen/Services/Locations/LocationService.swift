import Foundation
import OSLog
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
    
    /// Create a new location with photo using geocoded address data
    func createLocation(
        name: String,
        type: String,
        latitude: Double,
        longitude: Double,
        geocodedAddress: GeocodedAddress,
        photo: UIImage,
        photoLocation: CLLocation?,
        details: String? = nil,          // Location details (free-text from iOS form)
        productionDate: Date? = nil      // Optional production/filming date
    ) async throws -> Location {
        isLoading = true
        
        do {
            #if DEBUG
            Log.debug("Creating location", logger: Log.locations)
            #endif

            // Convert production date to ISO string if provided
            var productionDateString: String? = nil
            if let date = productionDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]  // YYYY-MM-DD only
                productionDateString = formatter.string(from: date)
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
                details: details,
                street: geocodedAddress.fullStreet,
                city: geocodedAddress.city,
                state: geocodedAddress.state,
                zipcode: geocodedAddress.zipcode
            )
            
            let response: CreateLocationResponse = try await apiClient.post(
                "/api/locations",
                body: createRequest
            )
            
            var location = response.userSave.location
            let userSaveId = response.userSave.id  // Store UserSave ID for fetching later
            location.userSaveId = userSaveId  // Set userSaveId for delete operations
            
            #if DEBUG
            Log.debug("Location created", logger: Log.locations)
            #endif
            
            // Step 2: Upload photo to the location
            do {
                _ = try await photoUploadService.uploadPhoto(
                    image: photo,
                    locationId: location.id,
                    location: photoLocation,
                    caption: nil
                )
                
                #if DEBUG
                Log.debug("Photo uploaded", logger: Log.photos)
                #endif
                
                // Step 3: Fetch the updated location using UserSave ID to get the photo data
                var updatedLocation = try await fetchLocation(userSaveId: userSaveId)
                updatedLocation.userSaveId = userSaveId  // Preserve userSaveId
                location = updatedLocation
            } catch {
                // Photo upload failed, but location was created
                Log.photos.error("Location created but photo upload failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
                // Continue anyway - location exists
            }
            
            isLoading = false
            return location
            
        } catch {
            isLoading = false
            
            Log.locations.error("Create location failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
            
            throw error
        }
    }
    
    // MARK: - Fetch Locations
    
    /// Fetch a single location by UserSave ID
    func fetchLocation(userSaveId: Int) async throws -> Location {
        if config.enableDebugLogging {
            Log.debug("Fetching location", logger: Log.locations)
        }
        
        do {
            let response: UserSaveDetailResponse = try await apiClient.get("/api/locations/\(userSaveId)")
            
            if config.enableDebugLogging {
                Log.debug("Fetched location", logger: Log.locations)
            }
            
            return response.userSave.location
        } catch {
            Log.locations.error("Fetch location failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
            throw error
        }
    }
    
    /// Fetch all locations for the current user
    func fetchLocations() async throws -> [Location] {
        if config.enableDebugLogging {
            dlog("LocationService", "Fetching locations...")
        }
        
        do {
            let response: LocationsResponse = try await apiClient.get("/api/locations")
            
            // Unwrap locations from UserSave objects
            let locations = response.unwrappedLocations
            
            if config.enableDebugLogging {
                dlog("LocationService", "Fetched \(locations.count) locations")
            }
            
            return locations
        } catch {
            Log.locations.error("Fetch locations failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
            throw error
        }
    }
    
    // MARK: - Delete Location
    
    /// Delete a location by UserSave ID
    func deleteLocation(userSaveId: Int) async throws {
        if config.enableDebugLogging {
            Log.debug("Deleting location", logger: Log.locations)
        }
        
        do {
            let _: EmptyResponse = try await apiClient.delete("/api/locations/\(userSaveId)")
            
            if config.enableDebugLogging {
                dlog("LocationService", "Location deleted successfully")
            }
        } catch {
            Log.locations.error("Delete location failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
            throw error
        }
    }

    // MARK: - Update Location

    /// Update a location via PATCH /api/locations/{locationId}
    /// Uses the Location ID (not UserSave ID). Handles both Location and UserSave fields.
    func updateLocation(locationId: Int, request: UpdateLocationRequest) async throws -> Location {
        #if DEBUG
        if config.enableDebugLogging {
            Log.debug("Updating location", logger: Log.locations)
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
                Log.debug("Location updated successfully", logger: Log.locations)
            }
            #endif

            return location
        } catch {
            Log.locations.error("Update location failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
            throw error
        }
    }

    // MARK: - Delete Photo

    /// Delete a photo by its ID via DELETE /api/photos/{photoId}
    func deletePhoto(photoId: Int) async throws {
        #if DEBUG
        if config.enableDebugLogging {
            Log.debug("Deleting photo", logger: Log.photos)
        }
        #endif

        do {
            let _: EmptyResponse = try await apiClient.delete("/api/photos/\(photoId)")

            #if DEBUG
            if config.enableDebugLogging {
                dlog("LocationService", "Photo deleted successfully")
            }
            #endif
        } catch {
            Log.photos.error("Delete photo failed; failure=\(Log.failure(error).rawValue, privacy: .public)")
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
