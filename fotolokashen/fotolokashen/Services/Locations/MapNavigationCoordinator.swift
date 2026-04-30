import Foundation
import Combine

/// Coordinates cross-tab navigation requests for the Map tab.
///
/// Phase 2b: extracted from `LocationStore`. Views post a focus request by
/// setting one of the published properties; `MapView` observes them and clears
/// the value once handled.
@MainActor
final class MapNavigationCoordinator: ObservableObject {
    static let shared = MapNavigationCoordinator()

    /// Owner-mode focus: open the user's own location in the map.
    @Published var mapFocusLocation: Location? = nil

    /// Read-only focus: open another user's public location in the map.
    @Published var mapFocusReadOnlyContext: ReadOnlyLocationContext? = nil

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
