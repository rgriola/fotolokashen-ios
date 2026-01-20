import Foundation
import Combine

/// Shared store for location data - ensures both MapView and LocationListView stay in sync
@MainActor
class LocationStore: ObservableObject {
    static let shared = LocationStore()
    
    @Published var locations: [Location] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let locationService = LocationService.shared
    private let config = ConfigLoader.shared
    
    private init() {}
    
    /// Fetch locations only if we don't have any (initial load)
    func fetchLocations() async {
        guard !isLoading else { return }
        
        // Only fetch if we don't have locations yet
        guard locations.isEmpty else {
            if config.enableDebugLogging {
                print("[LocationStore] Already have \(locations.count) locations, skipping fetch")
            }
            return
        }
        
        await refreshLocations()
    }
    
    /// Force refresh locations (for pull-to-refresh or after creating new location)
    func refreshLocations() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if config.enableDebugLogging {
                print("[LocationStore] Refreshing locations...")
            }
            
            locations = try await locationService.fetchLocations()
            
            if config.enableDebugLogging {
                print("[LocationStore] Refreshed \(locations.count) locations")
            }
        } catch {
            if config.enableDebugLogging {
                print("[LocationStore] Error refreshing locations: \(error)")
            }
            errorMessage = error.localizedDescription
        }
    }
    
    /// Add a newly created location to the store without refetching
    func addLocation(_ location: Location) {
        // Insert at beginning (newest first)
        locations.insert(location, at: 0)
        
        if config.enableDebugLogging {
            print("[LocationStore] Added location locally, now have \(locations.count) locations")
        }
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
