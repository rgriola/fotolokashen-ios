import XCTest
@testable import fotolokashen

@MainActor
final class AppIconsTests: XCTestCase {
    func testEveryCatalogSymbolExistsOnCurrentOS() {
        let missingSymbols = AppIcons.allSystemNames.filter {
            AppIcons.uiImage(for: $0) == nil
        }

        XCTAssertTrue(
            missingSymbols.isEmpty,
            "Unavailable SF Symbols: \(missingSymbols.joined(separator: ", "))"
        )
    }
}
