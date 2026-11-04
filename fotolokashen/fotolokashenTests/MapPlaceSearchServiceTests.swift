import MapKit
import Observation
import XCTest
@testable import fotolokashen

nonisolated final class MapPlaceSearchServiceTests: XCTestCase {
    @MainActor
    func testCompleterIsCreatedOnlyForNonEmptyQuery() {
        let service = MapPlaceSearchService()
        XCTAssertNil(service.completer)

        service.clear()
        XCTAssertNil(service.completer)

        service.queryFragment = "Coffee"
        XCTAssertEqual(service.completer?.queryFragment, "Coffee")
    }

    @MainActor
    func testQueryFragmentDidSetForwardsEveryChangeToCompleter() {
        let service = MapPlaceSearchService()
        service.queryFragment = "Cof"
        let completer = service.completer

        service.queryFragment = "Coffee"
        XCTAssertTrue(service.completer === completer)
        XCTAssertEqual(completer?.queryFragment, "Coffee")

        service.clear()
        XCTAssertEqual(service.queryFragment, "")
        XCTAssertEqual(completer?.queryFragment, "")
    }

    @MainActor
    func testQueryFragmentChangeNotifiesObservers() {
        let service = MapPlaceSearchService()
        let changed = expectation(description: "queryFragment change is observed")

        withObservationTracking {
            _ = service.queryFragment
        } onChange: {
            changed.fulfill()
        }
        service.queryFragment = "Park"

        wait(for: [changed], timeout: 0)
        XCTAssertEqual(service.completer?.queryFragment, "Park")
    }
}
