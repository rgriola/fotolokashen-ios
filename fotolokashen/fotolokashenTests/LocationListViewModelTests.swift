import XCTest
@testable import fotolokashen

/// Unit tests for `LocationListViewModel`'s pure merge/dedupe logic that combines
/// own locations with friends'/public locations for the "My Spots" list.
final class LocationListViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeLocation(id: Int, name: String = "Own", type: String = "BROLL") -> Location {
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
            thumbnailUrl: nil
        )
    }

    private func makeSocialLocation(id: Int, name: String = "Social", username: String = "friend1") -> MapSocialLocation {
        MapSocialLocation(
            id: id,
            placeId: "place-\(id)",
            name: name,
            address: "456 Side St",
            city: "Brooklyn",
            state: "NY",
            lat: 40.7,
            lng: -73.9,
            type: "BROLL",
            rating: nil,
            caption: nil,
            tags: nil,
            savedAt: "2026-01-15T12:00:00Z",
            user: SocialLocationUser(id: 99, username: username, firstName: "Friend", lastName: "One", avatar: nil)
        )
    }

    // MARK: - Tests

    func testMergeReturnsEmptyForEmptyInputs() {
        let result = LocationListViewModel.mergeLocations(own: [], friends: [], public: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testMergeOwnOnlyPreservesOrderAndSource() {
        let own = [makeLocation(id: 1, name: "A"), makeLocation(id: 2, name: "B")]

        let result = LocationListViewModel.mergeLocations(own: own, friends: [], public: [])

        XCTAssertEqual(result.map { $0.id }, [1, 2])
        XCTAssertTrue(result.allSatisfy { $0.source == .own })
    }

    func testMergeAppendsFriendsThenPublicAfterOwn() {
        let own = [makeLocation(id: 1)]
        let friends = [makeSocialLocation(id: 2)]
        let publicLocations = [makeSocialLocation(id: 3)]

        let result = LocationListViewModel.mergeLocations(own: own, friends: friends, public: publicLocations)

        XCTAssertEqual(result.map { $0.id }, [1, 2, 3])
        XCTAssertEqual(result.map { $0.source }, [.own, .friend, .public])
    }

    func testOwnLocationWinsOverDuplicateFriendId() {
        let own = [makeLocation(id: 5, name: "Mine")]
        let friends = [makeSocialLocation(id: 5, name: "Theirs")]

        let result = LocationListViewModel.mergeLocations(own: own, friends: friends, public: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.source, .own)
        XCTAssertEqual(result.first?.location.name, "Mine")
    }

    func testFriendWinsOverDuplicatePublicId() {
        let friends = [makeSocialLocation(id: 7, name: "FromFriend")]
        let publicLocations = [makeSocialLocation(id: 7, name: "FromPublic")]

        let result = LocationListViewModel.mergeLocations(own: [], friends: friends, public: publicLocations)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.source, .friend)
        XCTAssertEqual(result.first?.location.name, "FromFriend")
    }

    func testDuplicateIdsWithinSameSourceListCollapseToOne() {
        let friends = [makeSocialLocation(id: 8, name: "First"), makeSocialLocation(id: 8, name: "Second")]

        let result = LocationListViewModel.mergeLocations(own: [], friends: friends, public: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.location.name, "First")
    }

    func testFriendPublicSourcedLocationsCarrySocialLocationForNavigation() {
        let friendSocial = makeSocialLocation(id: 10)
        let result = LocationListViewModel.mergeLocations(own: [], friends: [friendSocial], public: [])

        XCTAssertEqual(result.first?.socialLocation, friendSocial)
    }

    func testOwnSourcedLocationHasNoSocialLocation() {
        let result = LocationListViewModel.mergeLocations(own: [makeLocation(id: 1)], friends: [], public: [])

        XCTAssertNil(result.first?.socialLocation)
    }
}
