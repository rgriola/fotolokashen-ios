import Foundation
import Combine

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

/// Facade kept for backward compatibility — Phase 2b split the original store
/// into:
///   • `LocationRepository` — owns `locations`, CRUD against the API.
///   • `MapNavigationCoordinator` — owns map focus requests.
///
/// Existing call-sites (`LocationStore.shared.locations`, `.refreshLocations()`,
/// `.mapFocusLocation = ...`, etc.) keep working through this facade. New code
/// should depend on `LocationRepository.shared` / `MapNavigationCoordinator.shared`
/// directly.
@MainActor
final class LocationStore: ObservableObject {
    static let shared = LocationStore()

    let repository: LocationRepository
    let coordinator: MapNavigationCoordinator

    private var cancellables = Set<AnyCancellable>()

    private init(
        repository: LocationRepository? = nil,
        coordinator: MapNavigationCoordinator? = nil
    ) {
        // Construct inside MainActor init body to satisfy Swift 6 isolation.
        self.repository = repository ?? LocationRepository.shared
        self.coordinator = coordinator ?? MapNavigationCoordinator.shared

        // Forward inner objectWillChange so existing @ObservedObject locationStore
        // call-sites keep getting view-update notifications.
        self.repository.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        self.coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
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
