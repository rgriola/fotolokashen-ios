import Foundation
import SwiftUI
import Combine

/// Phase 2a-1 — ViewModel for the unified `LocationDetailView`.
///
/// Owns all data state and async lifecycle for the detail screen so the view
/// stays thin and the data flow is independently testable. Mode (owner vs
/// read-only) is encoded in a single enum instead of being scattered across
/// initialisers + an `isReadOnly` flag.
@MainActor
final class LocationDetailViewModel: ObservableObject {

    // MARK: - Mode

    /// Distinguishes owner mode (editable, full metadata) from read-only mode
    /// (viewing someone else's public location).
    enum Mode: Equatable {
        case owner
        case readOnly(
            socialLocationId: Int?,
            ownerUsername: String,
            ownerDisplayName: String,
            inlinePhotos: [LocationPhoto]
        )

        var isReadOnly: Bool {
            if case .readOnly = self { return true }
            return false
        }

        var ownerUsername: String? {
            if case .readOnly(_, let username, _, _) = self { return username }
            return nil
        }

        var ownerDisplayName: String? {
            if case .readOnly(_, _, let name, _) = self { return name }
            return nil
        }

        var socialLocationId: Int? {
            if case .readOnly(let id, _, _, _) = self { return id }
            return nil
        }

        var inlinePhotos: [LocationPhoto] {
            if case .readOnly(_, _, _, let photos) = self { return photos }
            return []
        }
    }

    // MARK: - Published State

    @Published var currentLocation: Location
    @Published var photos: [DetailPhoto] = []
    @Published var isLoadingPhotos = true

    @Published var userSaveDetails: UserSaveWithLocation?
    @Published var isLoadingDetails = true

    @Published var locationVisibility: String
    @Published var isSavingVisibility = false

    // MARK: - Configuration

    let mode: Mode

    // MARK: - Init

    init(location: Location, mode: Mode) {
        self.currentLocation = location
        self.mode = mode
        // Read-only locations are always rendered as public; owner reads from model.
        if case .readOnly = mode {
            self.locationVisibility = "public"
        } else {
            self.locationVisibility = location.visibility ?? "private"
        }
    }

    // MARK: - Photo Loading

    /// Loads photos for this location.
    /// - Owner mode: fetches `/api/locations/{id}/photos`, with `currentLocation.photos` as fallback on failure.
    /// - Read-only mode: uses inline photos from `SocialLocation`; if empty,
    ///   falls back to fetching the owner's public locations and matching by id.
    func loadPhotos() async {
        if case .readOnly(let socialId, let username, _, let inline) = mode {
            if !inline.isEmpty {
                photos = DetailPhoto.fromLocationPhotos(inline)
                isLoadingPhotos = false
                return
            }
            guard !username.isEmpty else {
                isLoadingPhotos = false
                return
            }
            await fetchPhotosFromPublicProfile(
                username: username,
                socialLocationId: socialId
            )
            return
        }

        // Owner mode
        let locationId = currentLocation.id
        do {
            let response: PhotosResponse = try await APIClient.shared.get(
                "/api/locations/\(locationId)/photos"
            )
            photos = response.photos
            isLoadingPhotos = false
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[LocationDetailVM] Failed to load photos: \(error)")
            }
            #endif
            photos = DetailPhoto.fromLocationPhotos(currentLocation.photos ?? [])
            isLoadingPhotos = false
        }
    }

    /// Fetches photos from a user's public locations when inline photos are
    /// empty. Used when tapping a friend's marker on the map (which doesn't
    /// hydrate photos in the social-location payload).
    private func fetchPhotosFromPublicProfile(
        username: String,
        socialLocationId: Int?
    ) async {
        do {
            let response: UserLocationsResponse = try await APIClient.shared.get(
                "/api/v1/users/\(username)/locations",
                authenticated: true
            )

            let targetId = socialLocationId ?? currentLocation.id
            if let match = response.locations.first(where: { $0.location.id == targetId }) {
                photos = DetailPhoto.fromLocationPhotos(match.location.photos ?? [])
            } else {
                #if DEBUG
                if ConfigLoader.shared.enableDebugLogging {
                    print("[LocationDetailVM] Location \(targetId) not found in user's public locations")
                }
                #endif
            }
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[LocationDetailVM] Failed to fetch photos from public profile: \(error)")
            }
            #endif
        }
        isLoadingPhotos = false
    }

    // MARK: - User Save Details

    /// Loads the wrapped `UserSave` payload (owner mode only). Provides
    /// creator info shown next to the "Added" date in the header.
    func loadUserSaveDetails() async {
        guard !mode.isReadOnly else {
            isLoadingDetails = false
            return
        }
        guard let userSaveId = currentLocation.userSaveId else {
            isLoadingDetails = false
            return
        }
        do {
            let response: UserSaveDetailResponse = try await APIClient.shared.get(
                "/api/locations/\(userSaveId)"
            )
            userSaveDetails = response.userSave
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[LocationDetailVM] Failed to load user save details: \(error)")
            }
            #endif
        }
        isLoadingDetails = false
    }

    // MARK: - Visibility

    /// Changes the location's visibility (owner mode only).
    /// Optimistically updates UI; reverts on failure.
    func changeVisibility(_ newVisibility: String) {
        guard !mode.isReadOnly else { return }
        guard newVisibility != locationVisibility else { return }
        let previous = locationVisibility
        locationVisibility = newVisibility
        Task { [weak self] in
            guard let self else { return }
            self.isSavingVisibility = true
            var request = UpdateLocationRequest()
            request.visibility = newVisibility
            if let updated = await LocationStore.shared.updateLocation(
                self.currentLocation,
                request: request
            ) {
                self.currentLocation = updated
                self.locationVisibility = updated.visibility ?? "private"
            } else {
                self.locationVisibility = previous
            }
            self.isSavingVisibility = false
        }
    }

    // MARK: - Edit Apply

    /// Apply an edited location (returned from the edit sheet) and reload
    /// photo + user-save data.
    func applyEdited(_ updated: Location) async {
        currentLocation = updated
        await loadPhotos()
        await loadUserSaveDetails()
    }
}
