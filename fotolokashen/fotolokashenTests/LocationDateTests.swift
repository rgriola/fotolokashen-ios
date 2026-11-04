import XCTest
@testable import fotolokashen

/// Regression coverage for the dates and comparators used by My Spots.
final class LocationDateTests: XCTestCase {

    @MainActor
    private func makeLocation(id: Int = 1, createdAt: String) -> Location {
        Location(
            id: id,
            name: "Spot \(id)",
            address: "123 Main St",
            latitude: 40.7128,
            longitude: -74.0060,
            type: "BROLL",
            placeId: "place-\(id)",
            createdAt: createdAt,
            photosCount: 0,
            thumbnailUrl: nil
        )
    }

    @MainActor
    private func scrambledLocations() -> [Location] {
        [
            makeLocation(id: 3, createdAt: "2026-01-16T12:00:00.900Z"),
            makeLocation(id: 1, createdAt: "2026-01-16T12:00:00Z"),
            makeLocation(id: 4, createdAt: "2026-01-17T12:00:00Z"),
            makeLocation(id: 2, createdAt: "2026-01-16T12:00:00.100Z"),
            makeLocation(id: 5, createdAt: "not-a-date")
        ]
    }

    @MainActor
    func testCreatedDateParsesFractionalSecondsUTC() throws {
        let location = makeLocation(createdAt: "2026-01-16T12:00:00.123Z")
        let date = try XCTUnwrap(location.createdDate)

        // 2026-01-16 12:00:00 UTC, with milliseconds preserved.
        XCTAssertEqual(date.timeIntervalSince1970, 1_768_564_800.123, accuracy: 0.000_001)
    }

    @MainActor
    func testCreatedDateParsesWholeSecondsUTC() throws {
        let location = makeLocation(createdAt: "2026-01-16T12:00:00Z")
        let date = try XCTUnwrap(location.createdDate)

        XCTAssertEqual(date.timeIntervalSince1970, 1_768_564_800, accuracy: 0.000_001)
    }

    @MainActor
    func testFractionalTimezoneOffsetRepresentsSameInstantAsUTC() throws {
        let utc = makeLocation(createdAt: "2026-01-16T12:00:00.123Z")
        let offset = makeLocation(createdAt: "2026-01-16T17:30:00.123+05:30")
        let utcDate = try XCTUnwrap(utc.createdDate)
        let offsetDate = try XCTUnwrap(offset.createdDate)

        XCTAssertEqual(offsetDate, utcDate)
        XCTAssertEqual(offsetDate.timeIntervalSince1970, 1_768_564_800.123, accuracy: 0.000_001)
    }

    @MainActor
    func testMalformedCreatedDateRemainsNil() {
        let location = makeLocation(createdAt: "not-a-date")

        XCTAssertNil(location.createdDate)
    }

    @MainActor
    func testOldestFirstSortOrdersSubsecondsAndPlacesMalformedDateFirst() {
        var locations = scrambledLocations()

        // Same model comparator and nil fallback as LocationListView.
        locations.sort { ($0.createdDate ?? Date.distantPast) < ($1.createdDate ?? Date.distantPast) }

        XCTAssertEqual(locations.map { $0.id }, [5, 1, 2, 3, 4])
    }

    @MainActor
    func testNewestFirstSortOrdersSubsecondsAndPlacesMalformedDateLast() {
        var locations = scrambledLocations()

        // Same model comparator and nil fallback as LocationListView.
        locations.sort { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }

        XCTAssertEqual(locations.map { $0.id }, [4, 3, 2, 1, 5])
    }
}
