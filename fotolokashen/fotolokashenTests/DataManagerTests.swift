import XCTest
import SwiftData
@testable import fotolokashen

nonisolated final class DataManagerTests: XCTestCase {
    @MainActor
    func testLocationAndPhotoUpsertsMatchOnlyTheirIDs() throws {
        let manager = DataManager.shared
        let locationId = -190001
        let otherLocationId = -190002
        let locationIDs: Set<Int> = [locationId, otherLocationId]

        try removeFixtures(from: manager, locationIDs: locationIDs)
        defer {
            XCTAssertNoThrow(try removeFixtures(from: manager, locationIDs: locationIDs))
        }

        try manager.saveLocations([
            makeLocation(id: locationId, name: "Original", placeId: "original-place"),
            makeLocation(id: otherLocationId, name: "Unchanged")
        ])
        try manager.saveLocation(makeLocation(id: locationId, name: "Updated"))

        let locations = try manager.fetchLocations().filter { locationIDs.contains($0.id) }
        XCTAssertEqual(locations.count, 2)
        XCTAssertEqual(locations.first { $0.id == locationId }?.name, "Updated")
        XCTAssertEqual(locations.first { $0.id == locationId }?.toLocation().placeId, "original-place")
        XCTAssertEqual(locations.first { $0.id == otherLocationId }?.name, "Unchanged")

        let photoId = -190003
        let otherPhotoId = -190004
        try manager.savePhoto(makePhoto(id: photoId, caption: "Original"), locationId: locationId)
        try manager.savePhoto(makePhoto(id: otherPhotoId, caption: "Unchanged"), locationId: locationId)
        try manager.savePhoto(makePhoto(id: photoId, caption: "Updated"), locationId: locationId)

        let photos = try manager.fetchPhotos(for: locationId)
        XCTAssertEqual(photos.count, 2)
        XCTAssertEqual(photos.first { $0.id == photoId }?.caption, "Updated")
        XCTAssertEqual(photos.first { $0.id == photoId }?.url, "https://example.test/\(photoId)/Original.jpg")
        XCTAssertEqual(photos.first { $0.id == otherPhotoId }?.caption, "Unchanged")
    }

    @MainActor
    private func makeLocation(id: Int, name: String, placeId: String? = nil) -> Location {
        Location(
            id: id,
            name: name,
            address: "Test address",
            latitude: 0,
            longitude: 0,
            type: "test",
            placeId: placeId,
            createdAt: "2026-11-01T00:00:00Z",
            photosCount: nil,
            thumbnailUrl: nil
        )
    }

    @MainActor
    private func makePhoto(id: Int, caption: String) -> Photo {
        CachedPhoto(
            id: id,
            imagekitFilePath: "/test/\(id).jpg",
            url: "https://example.test/\(id)/\(caption).jpg",
            thumbnailUrl: "https://example.test/\(id)-thumbnail.jpg",
            caption: caption,
            uploadedAt: "2026-11-01T00:00:00Z",
            locationId: -190001
        ).toPhoto()
    }

    @MainActor
    private func removeFixtures(from manager: DataManager, locationIDs: Set<Int>) throws {
        for locationId in locationIDs {
            for photo in try manager.fetchPhotos(for: locationId) {
                manager.modelContext.delete(photo)
            }
        }
        for location in try manager.fetchLocations() where locationIDs.contains(location.id) {
            manager.modelContext.delete(location)
        }
        try manager.modelContext.save()
    }
}
