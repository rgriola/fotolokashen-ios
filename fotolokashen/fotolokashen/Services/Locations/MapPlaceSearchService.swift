import MapKit
import Observation

/// Wraps MKLocalSearchCompleter/MKLocalSearch to search Apple's map data (places,
/// addresses, POIs) for the Map tab search bar. Distinct from LocationStore's search,
/// which only searches the user's own saved Location records.
@Observable
@MainActor
final class MapPlaceSearchService: NSObject {
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    var queryFragment: String = "" {
        didSet {
            guard completer != nil || !queryFragment.isEmpty else { return }
            completerForUse().queryFragment = queryFragment
        }
    }
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    /// Created on the first non-empty query so the Map tab doesn't start a completer it never uses.
    @ObservationIgnored private(set) var completer: MKLocalSearchCompleter?
    @ObservationIgnored private var activeSearch: MKLocalSearch?

    private func completerForUse() -> MKLocalSearchCompleter {
        if let completer {
            return completer
        }

        let completer = MKLocalSearchCompleter()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        self.completer = completer
        return completer
    }

    func clear() {
        queryFragment = ""
        suggestions = []
        errorMessage = nil
        activeSearch?.cancel()
    }

    /// Resolves a tapped suggestion to a concrete coordinate + name.
    func resolve(_ completion: MKLocalSearchCompletion) async throws -> MKMapItem? {
        activeSearch?.cancel()
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        activeSearch = search
        let response = try await search.start()
        return response.mapItems.first
    }
}

extension MapPlaceSearchService: @MainActor MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        dlog("MapPlaceSearchService", "\(completer.results.count) suggestions for '\(queryFragment)'")
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        dlog("MapPlaceSearchService", "Search completion failed")
        errorMessage = error.localizedDescription
    }
}
