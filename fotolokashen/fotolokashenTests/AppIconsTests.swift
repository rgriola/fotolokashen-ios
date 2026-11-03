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

    /// The OS-presence check above passes on the newest simulator even for symbols
    /// that don't exist on older iOS versions. This checks each symbol's introduction
    /// release against the app's minimum iOS version using the SF Symbols metadata
    /// that ships with the simulator runtime.
    func testEveryCatalogSymbolExistsOnMinimumOS() throws {
        let minimumOS = try XCTUnwrap(
            Bundle.main.infoDictionary?["MinimumOSVersion"] as? String,
            "Host app has no MinimumOSVersion"
        )
        let root = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] ?? ""
        let url = URL(fileURLWithPath: root + "/System/Library/PrivateFrameworks/SFSymbols.framework/CoreGlyphs.bundle/name_availability.plist")
        guard let data = try? Data(contentsOf: url) else {
            throw XCTSkip("SF Symbols availability metadata not found at \(url.path)")
        }
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let symbols = try XCTUnwrap(plist["symbols"] as? [String: String])
        let releases = try XCTUnwrap(plist["year_to_release"] as? [String: [String: String]])

        let tooNew = AppIcons.allSystemNames.sorted().compactMap { name -> String? in
            guard let year = symbols[name] else { return "\(name) (unknown)" }
            guard let iOS = releases[year]?["iOS"] else { return "\(name) (no iOS release for \(year))" }
            return iOS.compare(minimumOS, options: .numeric) == .orderedDescending
                ? "\(name) (iOS \(iOS))" : nil
        }

        XCTAssertTrue(
            tooNew.isEmpty,
            "SF Symbols newer than iOS \(minimumOS): \(tooNew.joined(separator: ", "))"
        )
    }
}
