import XCTest
@testable import fotolokashen

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

        XCTAssertEqual(sut.getAccessToken(), "new-access", "Access token should be rotated")
        XCTAssertEqual(sut.getRefreshToken(), "refresh-1", "Refresh token must survive an access-token rotation")
        XCTAssertEqual(sut.getUserID(), 1, "Stored user id must survive an access-token rotation")
        XCTAssertEqual(
            sut.getTokenExpiry()?.timeIntervalSince1970 ?? 0,
            newExpiresAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }
}
