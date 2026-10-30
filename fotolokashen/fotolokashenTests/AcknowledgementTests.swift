import XCTest
@testable import fotolokashen

@MainActor
final class AcknowledgementTests: XCTestCase {
    func testEveryShippedAcknowledgementLoads() throws {
        for acknowledgement in Acknowledgement.allCases {
            XCTAssertFalse(try acknowledgement.text().isEmpty, acknowledgement.title)
        }
    }

    func testBundledLicenseContents() throws {
        XCTAssertTrue(try Acknowledgement.googleMapsPackage.text().contains("Apache License"))
        XCTAssertTrue(try Acknowledgement.googleMapsUtils.text().contains("Apache License"))
        let kingfisher = try Acknowledgement.kingfisher.text()
        XCTAssertTrue(kingfisher.contains("The MIT License"))
        XCTAssertTrue(kingfisher.contains("Copyright (c) 2019 Wei Wang"))
    }

    func testMissingResourceFailsExplicitly() {
        XCTAssertThrowsError(try Acknowledgement.kingfisher.text(bundle: Bundle(for: Self.self)))
    }

    func testStableUniqueIdentifiers() {
        XCTAssertEqual(Set(Acknowledgement.allCases.map(\.id)).count, 4)
    }
}
