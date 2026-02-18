import Foundation
import Combine

/// Manages deep link navigation state for the app.
/// Handles both custom URL scheme (`fotolokashen://`) and Universal Links (`https://fotolokashen.com/shared/`).
@MainActor
class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    /// When set, the app should present a location detail view for this location ID.
    @Published var pendingLocationId: Int?

    /// Whether a deep link location is currently being loaded.
    @Published var isLoadingDeepLink = false

    /// Error message if deep link resolution fails.
    @Published var deepLinkError: String?

    private init() {}

    // MARK: - URL Handling

    /// Process an incoming URL and extract navigation intent.
    /// Returns `true` if the URL was handled as a deep link (not OAuth).
    func handleURL(_ url: URL) -> Bool {
        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[DeepLink] Received URL: \(url.absoluteString)")
        }
        #endif

        // Custom scheme: fotolokashen://location/123
        if url.scheme == "fotolokashen" {
            if url.host == "location", let idString = url.pathComponents.last, let id = Int(idString) {
                navigateToLocation(id: id)
                return true
            }
            // OAuth callback — not a deep link
            if url.host == "oauth-callback" {
                return false
            }
        }

        // Universal Link: https://fotolokashen.com/shared/123
        if let host = url.host, host.contains("fotolokashen.com") {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 3, pathComponents[1] == "shared", let id = Int(pathComponents[2]) {
                navigateToLocation(id: id)
                return true
            }
        }

        return false
    }

    // MARK: - Navigation

    /// Set the pending location ID to trigger navigation.
    func navigateToLocation(id: Int) {
        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[DeepLink] Navigating to location ID: \(id)")
        }
        #endif

        deepLinkError = nil
        pendingLocationId = id
    }

    /// Clear the pending navigation after it has been handled.
    func clearPendingNavigation() {
        pendingLocationId = nil
        isLoadingDeepLink = false
        deepLinkError = nil
    }

    /// Resolve a location ID to a Location object.
    /// First checks the local store, then fetches from API if needed.
    func resolveLocation(id: Int) async -> Location? {
        isLoadingDeepLink = true
        deepLinkError = nil

        // Check local store first
        if let local = LocationStore.shared.locations.first(where: { $0.id == id }) {
            isLoadingDeepLink = false
            return local
        }

        // Not in local store — fetch all locations and search
        do {
            await LocationStore.shared.fetchLocations()
            if let found = LocationStore.shared.locations.first(where: { $0.id == id }) {
                isLoadingDeepLink = false
                return found
            } else {
                deepLinkError = "Location not found"
                isLoadingDeepLink = false
                return nil
            }
        }
    }
}
