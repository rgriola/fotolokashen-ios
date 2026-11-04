import Foundation
import XCTest
@testable import fotolokashen

nonisolated final class LocationRequestEncodingTests: XCTestCase {
    func testEmptyUpdateRequestOmitsUnsetFields() throws {
        let payload = try encodedPayload(UpdateLocationRequest())

        XCTAssertTrue(payload.isEmpty)
    }

    func testUpdateRequestEncodesProvidedValuesAndOmitsUnsetFields() throws {
        var request = UpdateLocationRequest()
        request.name = "Test location"
        request.isFavorite = false
        request.tags = ["test"]
        request.productionDate = "2026-04-15"

        let payload = try encodedPayload(request)

        XCTAssertEqual(payload["name"] as? String, "Test location")
        XCTAssertEqual(payload["isFavorite"] as? Bool, false)
        XCTAssertEqual(payload["tags"] as? [String], ["test"])
        XCTAssertEqual(payload["productionDate"] as? String, "2026-04-15")
        XCTAssertNil(payload["notes"])
        XCTAssertNil(payload["rating"])
    }

    private func encodedPayload(_ request: UpdateLocationRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
