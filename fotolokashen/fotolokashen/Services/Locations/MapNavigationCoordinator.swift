import Foundation
import Observation

/// Coordinates cross-tab navigation requests for the Map tab.
///
/// Phase 2b: extracted from `LocationStore`. Views post a focus request by
/// setting one of the observable properties; `MapView` observes them and clears
/// the value once handled.
@Observable
@MainActor
final class MapNavigationCoordinator {
    static let shared = MapNavigationCoordinator()

    /// Owner-mode focus: open the user's own location in the map.
    var mapFocusLocation: Location?

    /// Read-only focus: open another user's public location in the map.
    var mapFocusReadOnlyContext: ReadOnlyLocationContext?

    init() {}

    func focus(on location: Location) {
        mapFocusLocation = location
    }

    func focus(on context: ReadOnlyLocationContext) {
        mapFocusReadOnlyContext = context
    }

    func clear() {
        mapFocusLocation = nil
        mapFocusReadOnlyContext = nil
    }
}
