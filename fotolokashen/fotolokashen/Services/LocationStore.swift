import Foundation
import Combine

/// Shared store for location data - ensures both MapView and LocationListView stay in sync
@MainActor
class LocationStore: ObservableObject {
    static let shared = LocationStore()
    
    @Published var locations: [Location] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var mapFocusLocation: Location? = nil
    
    private let locationService = LocationService.shared
    private let config = ConfigLoader.shared
    
    private init() {}
    
    /// Fetch locations only if we don't have any (initial load)
    func fetchLocations() async {
        print("[LocationStore] 📡 fetchLocations() called, isLoading: \(isLoading), count: \(locations.count)")
        
        guard !isLoading else {
            print("[LocationStore] ⏳ Already loading, skipping")
            return
        }
        
        // Only fetch if we don't have locations yet
        guard locations.isEmpty else {
            print("[LocationStore] ℹ️ Already have \(locations.count) locations, skipping fetch")
            return
        }
        
        print("[LocationStore] 🔄 Locations empty, calling refreshLocations()...")
        await refreshLocations()
    }
    
    /// Force refresh locations (for pull-to-refresh or after creating new location)
    func refreshLocations() async {
        print("[LocationStore] 🔄 refreshLocations() called")
        
        guard !isLoading else {
            print("[LocationStore] ⏳ Already loading, skipping refresh")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("[LocationStore] 📡 Fetching from API...")
            
            locations = try await locationService.fetchLocations()
            
            print("[LocationStore] ✅ Refreshed \(locations.count) locations")
        } catch {
            print("[LocationStore] ❌ Error refreshing locations: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Add a newly created location to the store without refetching
    func addLocation(_ location: Location) {
        print("[LocationStore] 📍 Adding new location: \(location.name)")
        print("[LocationStore] 📍 Current count BEFORE add: \(locations.count)")
        
        // Insert at beginning (newest first)
        locations.insert(location, at: 0)
        
        print("[LocationStore] ✅ Added location, now have \(locations.count) locations")
    }
    
    /// Delete a location from the server and remove from local store
    /// Returns true if successful, false if failed
    @discardableResult
    func deleteLocation(_ location: Location) async -> Bool {
        guard let userSaveId = location.userSaveId else {
            if config.enableDebugLogging {
                print("[LocationStore] Error: Location has no userSaveId, cannot delete")
            }
            errorMessage = "Cannot delete location: missing identifier"
            return false
        }
        
        do {
            if config.enableDebugLogging {
                print("[LocationStore] Deleting location with UserSave ID: \(userSaveId)")
            }
            
            try await locationService.deleteLocation(userSaveId: userSaveId)
            
            // Remove from local array
            locations.removeAll { $0.id == location.id }
            
            if config.enableDebugLogging {
                print("[LocationStore] Location deleted successfully, now have \(locations.count) locations")
            }
            
            return true
        } catch {
            if config.enableDebugLogging {
                print("[LocationStore] Error deleting location: \(error)")
            }
            errorMessage = "Failed to delete location: \(error.localizedDescription)"
            return false
        }
    }

    /// Update a location on the server and in the local store
    /// Uses Location ID for the PATCH call, preserves UserSave ID
    @discardableResult
    func updateLocation(_ location: Location, request: UpdateLocationRequest) async -> Location? {
        do {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationStore] Updating location ID: \(location.id)")
            }
            #endif

            var updatedLocation = try await locationService.updateLocation(
                locationId: location.id,
                request: request
            )

            // Preserve the userSaveId from the original location if not returned
            if updatedLocation.userSaveId == nil {
                updatedLocation.userSaveId = location.userSaveId
            }

            // Update in local array
            if let index = locations.firstIndex(where: { $0.id == location.id }) {
                locations[index] = updatedLocation
            }

            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationStore] Location updated in store: \(updatedLocation.name)")
            }
            #endif

            return updatedLocation
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationStore] Error updating location: \(error)")
            }
            #endif
            errorMessage = "Failed to update location: \(error.localizedDescription)"
            return nil
        }
    }

    /// Delete a photo from a location
    @discardableResult
    func deletePhoto(photoId: Int, from location: Location) async -> Bool {
        do {
            try await locationService.deletePhoto(photoId: photoId)

            // Update the local location by removing the photo
            if let index = locations.firstIndex(where: { $0.id == location.id }) {
                // Re-fetch to get updated photos list
                if let userSaveId = location.userSaveId {
                    var refreshed = try await locationService.fetchLocation(userSaveId: userSaveId)
                    refreshed.userSaveId = userSaveId
                    // Preserve UserSave fields
                    refreshed.color = locations[index].color
                    refreshed.isFavorite = locations[index].isFavorite
                    refreshed.personalRating = locations[index].personalRating
                    refreshed.caption = locations[index].caption
                    refreshed.tags = locations[index].tags
                    refreshed.visibility = locations[index].visibility
                    locations[index] = refreshed
                }
            }

            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationStore] Photo \(photoId) deleted successfully")
            }
            #endif

            return true
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationStore] Error deleting photo: \(error)")
            }
            #endif
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Remove a location from the store (local only)
    func removeLocation(id: Int) {
        locations.removeAll { $0.id == id }
        
        if config.enableDebugLogging {
            print("[LocationStore] Removed location, now have \(locations.count) locations")
        }
    }
    
    /// Clear all data (for logout)
    func clear() {
        locations = []
        errorMessage = ""
        
        if config.enableDebugLogging {
            print("[LocationStore] Cleared all locations")
        }
    }
}
