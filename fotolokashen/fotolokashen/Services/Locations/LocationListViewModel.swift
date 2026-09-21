import Foundation
import Combine

/// Owns the "My Spots" screen's friends/public toggle state and data, and merges
/// them with the user's own locations (from `LocationStore`) into a single,
/// deduplicated, source-tagged list for `LocationListView`.
@MainActor
final class LocationListViewModel: ObservableObject {

    @Published private(set) var friendLocations: [MapSocialLocation] = []
    @Published private(set) var publicLocations: [MapSocialLocation] = []
    @Published private(set) var showFriends = false
    @Published private(set) var showPublic = false
    @Published private(set) var isLoadingFriends = false
    @Published private(set) var isLoadingPublic = false

    private let followService: FollowService

    init(followService: FollowService = .shared) {
        self.followService = followService
    }

    /// Merges the user's own locations with the currently-enabled friends/public sources.
    func mergedLocations(own: [Location]) -> [LocationWithSource] {
        Self.mergeLocations(
            own: own,
            friends: showFriends ? friendLocations : [],
            public: showPublic ? publicLocations : []
        )
    }

    // MARK: - Toggling

    func toggleFriends() async {
        showFriends.toggle()
        if showFriends && friendLocations.isEmpty {
            await loadFriends()
        }
    }

    func togglePublic() async {
        showPublic.toggle()
        if showPublic && publicLocations.isEmpty {
            await loadPublic()
        }
    }

    /// Re-fetches only the currently-enabled sources (used by pull-to-refresh).
    func refreshEnabledSources() async {
        async let friendsRefresh: Void = showFriends ? loadFriends() : {}()
        async let publicRefresh: Void = showPublic ? loadPublic() : {}()
        _ = await (friendsRefresh, publicRefresh)
    }

    // MARK: - Loading

    private func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        do {
            // Bounded so a hung request can't leave isLoadingFriends stuck true
            // with no in-app recovery path (see LocationRepository.refreshLocations).
            friendLocations = try await withTimeout(seconds: 45) { [followService] in
                try await followService.getFriendsLocations()
            }
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[LocationListViewModel] Failed to load friends locations: \(error)")
            }
            #endif
        }
    }

    private func loadPublic() async {
        isLoadingPublic = true
        defer { isLoadingPublic = false }
        do {
            publicLocations = try await withTimeout(seconds: 45) { [followService] in
                try await followService.getPublicLocations()
            }
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[LocationListViewModel] Failed to load public locations: \(error)")
            }
            #endif
        }
    }

    // MARK: - Merge (pure, unit-testable)

    /// Own locations take precedence, then friends, then public — first occurrence of
    /// a given location id wins, matching the web app's already-shipped merge behavior.
    nonisolated static func mergeLocations(
        own: [Location],
        friends: [MapSocialLocation],
        public publicLocations: [MapSocialLocation]
    ) -> [LocationWithSource] {
        var seen = Set<Int>()
        var result: [LocationWithSource] = []

        for location in own where seen.insert(location.id).inserted {
            result.append(LocationWithSource(location: location, source: .own, socialLocation: nil))
        }
        for social in friends where seen.insert(social.id).inserted {
            result.append(LocationWithSource(location: Location(socialLocation: social), source: .friend, socialLocation: social))
        }
        for social in publicLocations where seen.insert(social.id).inserted {
            result.append(LocationWithSource(location: Location(socialLocation: social), source: .public, socialLocation: social))
        }

        return result
    }
}
