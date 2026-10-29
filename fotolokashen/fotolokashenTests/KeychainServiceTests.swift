import XCTest
@testable import fotolokashen
import Security

final class KeychainServiceTests: XCTestCase {

    let sut = KeychainService.shared

    override func tearDownWithError() throws {
        try sut.clearTokens()
        try super.tearDownWithError()
    }

    /// Regression test for the token-refresh logout bug: refreshing the access token
    /// must not require (or wipe) the existing refresh token or user id.
    func testUpdateAccessTokenRotatesAccessTokenOnly() throws {
        let user = User(
            id: 1, email: "a@b.com", username: "user1", firstName: nil, lastName: nil,
            dateOfBirth: nil, avatar: nil, bannerImage: nil, bio: nil, city: nil,
            state: nil, country: nil, emailVerified: true, isActive: true, isAdmin: false,
            role: "user", createdAt: "2026-01-01T00:00:00Z", updatedAt: nil,
            language: nil, timezone: nil, emailNotifications: nil, gpsPermission: nil,
            gpsPermissionUpdated: nil, homeLocationName: nil, homeLocationLat: nil,
            homeLocationLng: nil, homeLocationUpdated: nil, profileVisibility: nil,
            showInSearch: nil, showLocation: nil, showSavedLocations: nil,
            allowFollowRequests: nil, onboardingCompleted: nil, termsAcceptedAt: nil,
            termsVersion: nil
        )
        let originalToken = OAuthToken(
            accessToken: "old-access", refreshToken: "refresh-1", tokenType: "Bearer",
            expiresIn: 86400, scope: "read write", user: user,
            expiresAt: Date().addingTimeInterval(86400)
        )
        try sut.saveToken(originalToken)

        let newExpiresAt = Date().addingTimeInterval(3600)
        try sut.updateAccessToken("new-access", expiresAt: newExpiresAt)

        XCTAssertEqual(try sut.getAccessToken(), "new-access", "Access token should be rotated")
        XCTAssertEqual(try sut.getRefreshToken(), "refresh-1", "Refresh token must survive an access-token rotation")
        XCTAssertEqual(try sut.getUserID(), 1, "Stored user id must survive an access-token rotation")
        XCTAssertEqual(
            try sut.getTokenExpiry()?.timeIntervalSince1970 ?? 0,
            newExpiresAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testMigrationPreservesAllLegacyKeychainAccessCredentials() throws {
        let legacyStore = InMemoryKeychainItemStore()
        legacyStore.seedLegacyCredentials()
        let service = KeychainService(store: legacyStore)

        XCTAssertEqual(try service.getAccessToken(), "legacy-access")
        XCTAssertEqual(try service.getRefreshToken(), "legacy-refresh")
        XCTAssertEqual(try service.getUserID(), 42)
        XCTAssertEqual(
            try service.getTokenExpiry()?.timeIntervalSince1970,
            1_900_000_000
        )
        XCTAssertTrue(legacyStore.allCredentialsUse(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly))
        XCTAssertEqual(legacyStore.removalCount, 0)
    }

    func testSecItemMigrationReadsLegacyKeychainAccessFormat() throws {
        try sut.clearTokens()
        try seedLegacyEntriesInSystemKeychain()
        let service = KeychainService(
            store: SecItemKeychainStore(service: KeychainService.serviceName)
        )

        XCTAssertEqual(try service.getAccessToken(), "legacy-access")
        XCTAssertEqual(try service.getRefreshToken(), "legacy-refresh")
        XCTAssertEqual(try service.getUserID(), 42)
        XCTAssertEqual(
            try service.getTokenExpiry()?.timeIntervalSince1970,
            1_900_000_000
        )
    }

    func testMigrationWriteFailureThrowsAndPreservesLegacyCredentials() throws {
        let legacyStore = InMemoryKeychainItemStore()
        legacyStore.seedLegacyCredentials()
        legacyStore.failWrites = true
        let service = KeychainService(store: legacyStore)

        XCTAssertThrowsError(try service.getAccessToken())
        XCTAssertThrowsError(try service.getRefreshToken())
        XCTAssertEqual(legacyStore.credentialValues, InMemoryKeychainItemStore.legacyValues)
        XCTAssertEqual(legacyStore.removalCount, 0)
    }

    func testPartialMigrationWriteFailurePreservesAllLegacyCredentialBytes() throws {
        let legacyStore = InMemoryKeychainItemStore()
        legacyStore.seedLegacyCredentials()
        legacyStore.failWriteNumber = 2
        let service = KeychainService(store: legacyStore)

        XCTAssertThrowsError(try service.getAccessToken())
        XCTAssertEqual(legacyStore.credentialValues, InMemoryKeychainItemStore.legacyValues)
        XCTAssertEqual(legacyStore.removalCount, 0)
    }

    func testMigrationReadFailureThrowsBeforeAnyWriteOrRemoval() throws {
        let legacyStore = InMemoryKeychainItemStore()
        legacyStore.seedLegacyCredentials()
        legacyStore.failReads = true
        let service = KeychainService(store: legacyStore)

        XCTAssertThrowsError(try service.getAccessToken())
        XCTAssertEqual(legacyStore.writeCount, 0)
        XCTAssertEqual(legacyStore.credentialValues, InMemoryKeychainItemStore.legacyValues)
        XCTAssertEqual(legacyStore.removalCount, 0)
    }

    func testMigrationVerificationFailureThrowsWithoutDeletingCredentialValues() throws {
        let legacyStore = InMemoryKeychainItemStore()
        legacyStore.seedLegacyCredentials()
        legacyStore.corruptVerificationReads = true
        let service = KeychainService(store: legacyStore)

        XCTAssertThrowsError(try service.getAccessToken())
        XCTAssertEqual(legacyStore.credentialValues, InMemoryKeychainItemStore.legacyValues)
        XCTAssertEqual(legacyStore.removalCount, 0)
    }

    private func seedLegacyEntriesInSystemKeychain() throws {
        let entries: [(String, String)] = [
            ("access_token", "legacy-access"),
            ("refresh_token", "legacy-refresh"),
            ("token_expiry", "1900000000.0"),
            ("user_id", "42")
        ]
        for (account, value) in entries {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: KeychainService.serviceName,
                kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: false,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
                kSecValueData as String: Data(value.utf8)
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            XCTAssertEqual(status, errSecSuccess, "Could not seed a legacy-format keychain item")
        }
    }
}

private final class InMemoryKeychainItemStore: KeychainItemStore {
    static let legacyValues: [String: Data] = [
        "access_token": Data("legacy-access".utf8),
        "refresh_token": Data("legacy-refresh".utf8),
        "token_expiry": Data("1900000000.0".utf8),
        "user_id": Data("42".utf8)
    ]

    private(set) var credentialValues: [String: Data] = [:]
    private var accessibilities: [String: CFString] = [:]
    private(set) var writeCount = 0
    private(set) var removalCount = 0
    var failReads = false
    var failWrites = false
    var failWriteNumber: Int?
    var corruptVerificationReads = false

    func seedLegacyCredentials() {
        credentialValues = Self.legacyValues
        accessibilities = Dictionary(uniqueKeysWithValues: Self.legacyValues.keys.map {
            ($0, kSecAttrAccessibleWhenUnlocked)
        })
    }

    func read(account: String) throws -> Data? {
        if failReads { throw TestKeychainError.injectedFailure }
        if corruptVerificationReads && writeCount > 0 {
            return Data("verification-mismatch".utf8)
        }
        return credentialValues[account]
    }

    func set(_ data: Data, account: String, accessibility: CFString) throws {
        writeCount += 1
        if failWrites || writeCount == failWriteNumber {
            throw TestKeychainError.injectedFailure
        }
        credentialValues[account] = data
        accessibilities[account] = accessibility
    }

    func remove(account: String) throws {
        removalCount += 1
        credentialValues.removeValue(forKey: account)
        accessibilities.removeValue(forKey: account)
    }

    func allCredentialsUse(_ accessibility: CFString) -> Bool {
        accessibilities.values.allSatisfy { CFEqual($0, accessibility) }
    }
}

private enum TestKeychainError: Error {
    case injectedFailure
}
