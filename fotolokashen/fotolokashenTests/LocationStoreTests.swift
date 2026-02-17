import XCTest
@testable import fotolokashen

@MainActor
final class LocationStoreTests: XCTestCase {

    var sut: LocationStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = LocationStore.shared
        sut.locations = [] // Clear any existing data
        sut.errorMessage = ""
    }

    override func tearDownWithError() throws {
        sut.clear()
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper

    private func makeLocation(id: Int, name: String = "Test", type: String = "BROLL", userSaveId: Int? = nil) -> Location {
        Location(
            id: id,
            name: name,
            address: "123 Main St",
            latitude: 40.7128,
            longitude: -74.0060,
            type: type,
            placeId: "place-\(id)",
            createdAt: "2026-01-16T12:00:00Z",
            photosCount: 0,
            thumbnailUrl: nil,
            userSaveId: userSaveId
        )
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(sut.locations.isEmpty, "Locations should be empty initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertEqual(sut.errorMessage, "", "Should have no error initially")
    }

    // MARK: - Add Location Tests

    func testAddLocation() {
        // Given
        let testLocation = makeLocation(id: 1, name: "Test Location")

        // When
        sut.addLocation(testLocation)

        // Then
        XCTAssertEqual(sut.locations.count, 1, "Should have one location")
        XCTAssertEqual(sut.locations.first?.id, 1, "Location ID should match")
        XCTAssertEqual(sut.locations.first?.name, "Test Location", "Location name should match")
    }

    func testAddMultipleLocations() {
        // Given
        let location1 = makeLocation(id: 1, name: "Location 1")
        let location2 = makeLocation(id: 2, name: "Location 2")

        // When
        sut.addLocation(location1)
        sut.addLocation(location2)

        // Then
        XCTAssertEqual(sut.locations.count, 2, "Should have two locations")
    }

    // MARK: - Remove Location Tests

    func testRemoveLocation() {
        // Given
        let location = makeLocation(id: 1)
        sut.addLocation(location)

        // When
        sut.removeLocation(id: location.id)

        // Then
        XCTAssertTrue(sut.locations.isEmpty, "Locations should be empty after removal")
    }

    func testRemoveLocationFromMultiple() {
        // Given
        let location1 = makeLocation(id: 1, name: "Location 1")
        let location2 = makeLocation(id: 2, name: "Location 2")
        sut.addLocation(location1)
        sut.addLocation(location2)

        // When
        sut.removeLocation(id: location1.id)

        // Then
        XCTAssertEqual(sut.locations.count, 1, "Should have one location remaining")
        XCTAssertEqual(sut.locations.first?.id, 2, "Remaining location should be location 2")
    }

    // MARK: - Clear Tests

    func testClearLocations() {
        // Given
        let location1 = makeLocation(id: 1)
        let location2 = makeLocation(id: 2)
        sut.addLocation(location1)
        sut.addLocation(location2)

        // When
        sut.clear()

        // Then
        XCTAssertTrue(sut.locations.isEmpty, "Locations should be empty after clearing")
    }

    // MARK: - Error Handling Tests

    func testErrorMessageHandling() {
        // Given
        let errorMessage = "Test error message"

        // When
        sut.errorMessage = errorMessage

        // Then
        XCTAssertEqual(sut.errorMessage, errorMessage, "Error message should be set")

        // When clearing
        sut.errorMessage = ""

        // Then
        XCTAssertEqual(sut.errorMessage, "", "Error message should be cleared")
    }

    // MARK: - Loading State Tests

    func testLoadingState() {
        // Initially false
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")

        // When set to loading
        sut.isLoading = true
        XCTAssertTrue(sut.isLoading, "Should be loading")

        // When loading complete
        sut.isLoading = false
        XCTAssertFalse(sut.isLoading, "Should not be loading after completion")
    }
}
