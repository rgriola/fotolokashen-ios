import XCTest
@testable import fotolokashen

@MainActor
final class LocationStoreTests: XCTestCase {
    
    var sut: LocationStore!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = LocationStore()
        sut.locations = [] // Clear any existing data
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Then
        XCTAssertTrue(sut.locations.isEmpty, "Locations should be empty initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertNil(sut.errorMessage, "Should have no error initially")
    }
    
    // MARK: - Add Location Tests
    
    func testAddLocation() {
        // Given
        let testLocation = Location(
            id: 1,
            name: "Test Location",
            locationTypeId: 1,
            latitude: 40.7128,
            longitude: -74.0060,
            formattedAddress: "New York, NY",
            userId: 1,
            createdAt: "2026-01-16T12:00:00Z"
        )
        
        // When
        sut.addLocation(testLocation)
        
        // Then
        XCTAssertEqual(sut.locations.count, 1, "Should have one location")
        XCTAssertEqual(sut.locations.first?.id, 1, "Location ID should match")
        XCTAssertEqual(sut.locations.first?.name, "Test Location", "Location name should match")
    }
    
    func testAddMultipleLocations() {
        // Given
        let location1 = Location(id: 1, name: "Location 1", locationTypeId: 1, latitude: 40.0, longitude: -74.0, formattedAddress: "Address 1", userId: 1, createdAt: "2026-01-16T12:00:00Z")
        let location2 = Location(id: 2, name: "Location 2", locationTypeId: 1, latitude: 41.0, longitude: -75.0, formattedAddress: "Address 2", userId: 1, createdAt: "2026-01-16T12:01:00Z")
        
        // When
        sut.addLocation(location1)
        sut.addLocation(location2)
        
        // Then
        XCTAssertEqual(sut.locations.count, 2, "Should have two locations")
    }
    
    // MARK: - Remove Location Tests
    
    func testRemoveLocation() {
        // Given
        let location = Location(id: 1, name: "Test", locationTypeId: 1, latitude: 40.0, longitude: -74.0, formattedAddress: "Address", userId: 1, createdAt: "2026-01-16T12:00:00Z")
        sut.addLocation(location)
        
        // When
        sut.removeLocation(location)
        
        // Then
        XCTAssertTrue(sut.locations.isEmpty, "Locations should be empty after removal")
    }
    
    func testRemoveLocationFromMultiple() {
        // Given
        let location1 = Location(id: 1, name: "Location 1", locationTypeId: 1, latitude: 40.0, longitude: -74.0, formattedAddress: "Address 1", userId: 1, createdAt: "2026-01-16T12:00:00Z")
        let location2 = Location(id: 2, name: "Location 2", locationTypeId: 1, latitude: 41.0, longitude: -75.0, formattedAddress: "Address 2", userId: 1, createdAt: "2026-01-16T12:01:00Z")
        sut.addLocation(location1)
        sut.addLocation(location2)
        
        // When
        sut.removeLocation(location1)
        
        // Then
        XCTAssertEqual(sut.locations.count, 1, "Should have one location remaining")
        XCTAssertEqual(sut.locations.first?.id, 2, "Remaining location should be location 2")
    }
    
    // MARK: - Update Location Tests
    
    func testUpdateLocation() {
        // Given
        let originalLocation = Location(id: 1, name: "Original Name", locationTypeId: 1, latitude: 40.0, longitude: -74.0, formattedAddress: "Original Address", userId: 1, createdAt: "2026-01-16T12:00:00Z")
        sut.addLocation(originalLocation)
        
        // When
        let updatedLocation = Location(id: 1, name: "Updated Name", locationTypeId: 1, latitude: 40.0, longitude: -74.0, formattedAddress: "Updated Address", userId: 1, createdAt: "2026-01-16T12:00:00Z")
        sut.updateLocation(updatedLocation)
        
        // Then
        XCTAssertEqual(sut.locations.count, 1, "Should still have one location")
        XCTAssertEqual(sut.locations.first?.name, "Updated Name", "Name should be updated")
        XCTAssertEqual(sut.locations.first?.formattedAddress, "Updated Address", "Address should be updated")
    }
    
    // MARK: - Clear Tests
    
    func testClearLocations() {
        // Given
        let location1 = Location(id: 1, name: "Location 1", locationTypeId: 1, latitude: 40.0, longitude: -74.0, formattedAddress: "Address 1", userId: 1, createdAt: "2026-01-16T12:00:00Z")
        let location2 = Location(id: 2, name: "Location 2", locationTypeId: 1, latitude: 41.0, longitude: -75.0, formattedAddress: "Address 2", userId: 1, createdAt: "2026-01-16T12:01:00Z")
        sut.addLocation(location1)
        sut.addLocation(location2)
        
        // When
        sut.locations.removeAll()
        
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
        sut.errorMessage = nil
        
        // Then
        XCTAssertNil(sut.errorMessage, "Error message should be cleared")
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
