import Foundation
import Combine

/// Owns the canonical list of the current user's saved locations and all
/// CRUD operations against `LocationService`.
///
/// Phase 2b: extracted from the legacy `LocationStore` singleton so the data
/// layer can be tested and reused independent of map-navigation concerns.
@MainActor
final class LocationRepository: ObservableObject {
    static let shared = LocationRepository()

    @Published var locations: [Location] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let locationService: LocationService
    private let config = ConfigLoader.shared

    init(locationService: LocationService? = nil) {
        // Construct inside MainActor init body to satisfy Swift 6 isolation.
        self.locationService = locationService ?? LocationService.shared
    }

    /// Fetch locations only if we don't have any (initial load).
    func fetchLocations() async {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationRepository] fetchLocations() called, isLoading: \(isLoading), count: \(locations.count)")
        }
        #endif

        guard !isLoading else { return }
        guard locations.isEmpty else { return }

        await refreshLocations()
    }

    /// Force refresh locations (for pull-to-refresh or after creating new location).
    func refreshLocations() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            locations = try await locationService.fetchLocations()
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationRepository] Refreshed \(locations.count) locations")
            }
            #endif
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationRepository] Error refreshing locations: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
        }
    }

    /// Add a newly created location to the store without refetching.
    func addLocation(_ location: Location) {
        locations.insert(location, at: 0)
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationRepository] Added location, now have \(locations.count)")
        }
        #endif
    }

    /// Replace the in-memory locations array (used by the SwiftData sync path).
    func replaceLocations(_ newLocations: [Location]) {
        locations = newLocations
    }

    /// Delete a location from the server and remove from local store.
    @discardableResult
    func deleteLocation(_ location: Location) async -> Bool {
        guard let userSaveId = location.userSaveId else {
            errorMessage = "Cannot delete location: missing identifier"
            return false
        }

        do {
            try await locationService.deleteLocation(userSaveId: userSaveId)
            locations.removeAll { $0.id == location.id }
            return true
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationRepository] Error deleting location: \(error)")
            }
            #endif
            errorMessage = "Failed to delete location: \(error.localizedDescription)"
            return false
        }
    }

    /// Update a location on the server and in the local store.
    @discardableResult
    func updateLocation(_ location: Location, request: UpdateLocationRequest) async -> Location? {
        do {
            var updatedLocation = try await locationService.updateLocation(
                locationId: location.id,
                request: request
            )

            // Preserve the userSaveId from the original location if not returned
            if updatedLocation.userSaveId == nil {
                updatedLocation.userSaveId = location.userSaveId
            }

            if let index = locations.firstIndex(where: { $0.id == location.id }) {
                locations[index] = updatedLocation
            }

            return updatedLocation
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationRepository] Error updating location: \(error)")
            }
            #endif
            errorMessage = "Failed to update location: \(error.localizedDescription)"
            return nil
        }
    }

    /// Delete a photo from a location and refresh the location's photos list.
    @discardableResult
    func deletePhoto(photoId: Int, from location: Location) async -> Bool {
        do {
            try await locationService.deletePhoto(photoId: photoId)

            if let index = locations.firstIndex(where: { $0.id == location.id }) {
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

            return true
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[LocationRepository] Error deleting photo: \(error)")
            }
            #endif
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
            return false
        }
    }

    /// Remove a location from the store (local only).
    func removeLocation(id: Int) {
        locations.removeAll { $0.id == id }
    }

    /// Clear all data (for logout).
    func clear() {
        locations = []
        errorMessage = ""
    }
}
