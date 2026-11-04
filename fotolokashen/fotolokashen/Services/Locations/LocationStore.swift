import Foundation

/// Context for displaying a read-only location on the map.
/// Used when navigating from PublicProfileView → LocationDetailView (read-only) → Map.
struct ReadOnlyLocationContext: Identifiable, Equatable {
    let id: Int  // The social location ID (for share URL)
    let location: Location
    let ownerUsername: String
    let ownerDisplayName: String
    let photos: [LocationPhoto]

    static func == (lhs: ReadOnlyLocationContext, rhs: ReadOnlyLocationContext) -> Bool {
        lhs.id == rhs.id
    }
}

extension ReadOnlyLocationContext {
    /// Synthesizes a read-only context from a friend's/public `MapSocialLocation`.
    /// Shared by the Map screen and My Spots list so both navigate to the same read-only detail view.
    init(socialLocation: MapSocialLocation) {
        self.init(
            id: socialLocation.id,
            location: Location(socialLocation: socialLocation),
            ownerUsername: socialLocation.user?.username ?? "",
            ownerDisplayName: socialLocation.user?.displayName ?? "",
            photos: []
        )
    }
}

/// Facade kept for backward compatibility — Phase 2b split the original store
/// into:
///   • `LocationRepository` — owns `locations`, CRUD against the API.
///   • `MapNavigationCoordinator` — owns map focus requests.
///
/// Existing call-sites (`LocationStore.shared.locations`, `.refreshLocations()`,
/// `.mapFocusLocation = ...`, etc.) keep working through this facade. New code
/// should depend on `LocationRepository.shared` / `MapNavigationCoordinator.shared`
/// directly.
///
/// The facade holds no observable state of its own: its pass-throughs read
/// the `@Observable` repository and coordinator, so SwiftUI tracks those
/// inner properties directly.
@MainActor
final class LocationStore {
    static let shared = LocationStore()

    let repository: LocationRepository
    let coordinator: MapNavigationCoordinator

    private init(
        repository: LocationRepository? = nil,
        coordinator: MapNavigationCoordinator? = nil
    ) {
        // Construct inside MainActor init body to satisfy Swift 6 isolation.
        self.repository = repository ?? LocationRepository.shared
        self.coordinator = coordinator ?? MapNavigationCoordinator.shared
    }

    // MARK: - Repository pass-through

    var locations: [Location] {
        get { repository.locations }
        set { repository.locations = newValue }
    }

    var isLoading: Bool {
        get { repository.isLoading }
        set { repository.isLoading = newValue }
    }

    var errorMessage: String {
        get { repository.errorMessage }
        set { repository.errorMessage = newValue }
    }

    func fetchLocations() async { await repository.fetchLocations() }
    func refreshLocations() async { await repository.refreshLocations() }
    func addLocation(_ location: Location) { repository.addLocation(location) }

    @discardableResult
    func deleteLocation(_ location: Location) async -> Bool {
        await repository.deleteLocation(location)
    }

    @discardableResult
    func updateLocation(_ location: Location, request: UpdateLocationRequest) async -> Location? {
        await repository.updateLocation(location, request: request)
    }

    @discardableResult
    func deletePhoto(photoId: Int, from location: Location) async -> Bool {
        await repository.deletePhoto(photoId: photoId, from: location)
    }

    func removeLocation(id: Int) { repository.removeLocation(id: id) }

    func clear() {
        repository.clear()
        coordinator.clear()
    }

    // MARK: - Coordinator pass-through

    var mapFocusLocation: Location? {
        get { coordinator.mapFocusLocation }
        set { coordinator.mapFocusLocation = newValue }
    }

    var mapFocusReadOnlyContext: ReadOnlyLocationContext? {
        get { coordinator.mapFocusReadOnlyContext }
        set { coordinator.mapFocusReadOnlyContext = newValue }
    }
}
