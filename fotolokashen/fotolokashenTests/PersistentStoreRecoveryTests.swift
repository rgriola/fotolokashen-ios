import Foundation
import XCTest
@testable import fotolokashen

final class PersistentStoreRecoveryTests: XCTestCase {

    func testSuccessfulCreationDoesNotQuarantineOrRetry() throws {
        var creationAttempts = 0
        var quarantineAttempts = 0

        let result = try PersistentStoreRecovery.open(
            createStore: {
                creationAttempts += 1
                return "existing"
            },
            quarantineStore: {
                quarantineAttempts += 1
                return nil
            }
        )

        XCTAssertEqual(result.store, "existing")
        XCTAssertNil(result.quarantinedStoreURL)
        XCTAssertEqual(creationAttempts, 1)
        XCTAssertEqual(quarantineAttempts, 0)
    }

    func testCreationFailureQuarantinesThenRetriesExactlyOnce() throws {
        var creationAttempts = 0
        var quarantineAttempts = 0
        let quarantineURL = URL(fileURLWithPath: "/recovery/store")

        let result = try PersistentStoreRecovery.open(
            createStore: {
                creationAttempts += 1
                if creationAttempts == 1 {
                    throw TestStoreError.unreadable
                }
                return "fresh"
            },
            quarantineStore: {
                quarantineAttempts += 1
                return quarantineURL
            }
        )

        XCTAssertEqual(result.store, "fresh")
        XCTAssertEqual(result.quarantinedStoreURL, quarantineURL)
        XCTAssertEqual(creationAttempts, 2)
        XCTAssertEqual(quarantineAttempts, 1)
    }

    func testRetryFailureReportsBothFailuresAndDoesNotRetryAgain() {
        var creationAttempts = 0
        var quarantineAttempts = 0

        XCTAssertThrowsError(
            try PersistentStoreRecovery.open(
                createStore: {
                    creationAttempts += 1
                    throw creationAttempts == 1
                        ? TestStoreError.unreadable
                        : TestStoreError.cannotCreateFreshStore
                },
                quarantineStore: {
                    quarantineAttempts += 1
                    return nil
                }
            )
        ) { error in
            guard let recoveryFailure = error as? StoreRecoveryFailure else {
                return XCTFail("Expected StoreRecoveryFailure, got \(error)")
            }
            XCTAssertEqual(
                recoveryFailure.initialError as? TestStoreError,
                .unreadable
            )
            XCTAssertEqual(
                recoveryFailure.retryError as? TestStoreError,
                .cannotCreateFreshStore
            )
        }

        XCTAssertEqual(creationAttempts, 2)
        XCTAssertEqual(quarantineAttempts, 1)
    }

    func testQuarantineFailurePreventsRetry() {
        var creationAttempts = 0

        XCTAssertThrowsError(
            try PersistentStoreRecovery.open(
                createStore: {
                    creationAttempts += 1
                    throw TestStoreError.unreadable
                },
                quarantineStore: {
                    throw TestStoreError.cannotQuarantine
                }
            )
        ) { error in
            XCTAssertEqual(error as? TestStoreError, .cannotQuarantine)
        }

        XCTAssertEqual(creationAttempts, 1)
    }

    func testQuarantinePreservesStoreAndSQLiteSidecars() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let storeURL = temporaryDirectory.appendingPathComponent("default.store")
        let expectedContents = [
            "default.store": Data("database".utf8),
            "default.store-wal": Data("write-ahead-log".utf8),
            "default.store-shm": Data("shared-memory".utf8)
        ]
        for (filename, contents) in expectedContents {
            try contents.write(to: temporaryDirectory.appendingPathComponent(filename))
        }

        let quarantineRoot = temporaryDirectory.appendingPathComponent(
            "recovery",
            isDirectory: true
        )
        let quarantineURL = try XCTUnwrap(
            PersistentStoreRecovery.quarantineSQLiteStore(
                at: storeURL,
                fileManager: fileManager,
                recoveryRootURL: quarantineRoot
            )
        )

        for (filename, contents) in expectedContents {
            let quarantinedFile = quarantineURL.appendingPathComponent(filename)
            XCTAssertEqual(try Data(contentsOf: quarantinedFile), contents)
            XCTAssertFalse(
                fileManager.fileExists(
                    atPath: temporaryDirectory.appendingPathComponent(filename).path
                )
            )
        }
    }

    private enum TestStoreError: Error, Equatable {
        case unreadable
        case cannotCreateFreshStore
        case cannotQuarantine
    }
}
