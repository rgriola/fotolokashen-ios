import MapKit
import Combine

/// Wraps MKLocalSearchCompleter/MKLocalSearch to search Apple's map data (places,
/// addresses, POIs) for the Map tab search bar. Distinct from LocationStore's search,
/// which only searches the user's own saved Location records.
@MainActor
final class MapPlaceSearchService: NSObject, ObservableObject {
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []
    @Published var queryFragment: String = "" {
        didSet { completer.queryFragment = queryFragment }
    }
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private var activeSearch: MKLocalSearch?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
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

extension MapPlaceSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        dlog("MapPlaceSearchService", "\(completer.results.count) suggestions for '\(queryFragment)'")
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        dlog("MapPlaceSearchService", "completer error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
    }
}
