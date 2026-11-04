import Observation
import XCTest
@testable import fotolokashen

@MainActor
final class DeepLinkManagerTests: XCTestCase {

    private let sut = DeepLinkManager.shared

    override func setUp() async throws {
        try await super.setUp()
        sut.clearPendingNavigation()
        sut.autoLoginToken = nil
        sut.emailVerified = false
        sut.passwordResetComplete = false
    }

    override func tearDown() async throws {
        sut.clearPendingNavigation()
        sut.autoLoginToken = nil
        sut.emailVerified = false
        sut.passwordResetComplete = false
        try await super.tearDown()
    }

    func testLocationNavigationIsObservable() {
        let changed = expectation(description: "Pending deep-link navigation is observed")
        withObservationTracking {
            _ = sut.pendingLocationId
        } onChange: {
            changed.fulfill()
        }

        XCTAssertTrue(sut.handleURL(URL(string: "fotolokashen://location/123")!))

        wait(for: [changed], timeout: 0)
        XCTAssertEqual(sut.pendingLocationId, 123)
    }

    func testClearingNavigationAndLoadingAndErrorIsObservable() {
        sut.navigateToLocation(id: 123)
        sut.isLoadingDeepLink = true
        sut.deepLinkError = "Location not found"
        let navigationChanged = expectation(description: "Cleared navigation is observed")
        let loadingChanged = expectation(description: "Cleared loading state is observed")
        let errorChanged = expectation(description: "Cleared error is observed")
        withObservationTracking {
            _ = sut.pendingLocationId
        } onChange: {
            navigationChanged.fulfill()
        }
        withObservationTracking {
            _ = sut.isLoadingDeepLink
        } onChange: {
            loadingChanged.fulfill()
        }
        withObservationTracking {
            _ = sut.deepLinkError
        } onChange: {
            errorChanged.fulfill()
        }

        sut.clearPendingNavigation()

        wait(for: [navigationChanged, loadingChanged, errorChanged], timeout: 0)
        XCTAssertNil(sut.pendingLocationId)
        XCTAssertFalse(sut.isLoadingDeepLink)
        XCTAssertNil(sut.deepLinkError)
    }

    func testEmailVerificationAndAutoLoginTokenAreObservable() {
        let verifiedChanged = expectation(description: "Email verification is observed")
        let tokenChanged = expectation(description: "Auto-login token is observed")
        withObservationTracking {
            _ = sut.emailVerified
        } onChange: {
            verifiedChanged.fulfill()
        }
        withObservationTracking {
            _ = sut.autoLoginToken
        } onChange: {
            tokenChanged.fulfill()
        }

        XCTAssertTrue(sut.handleURL(URL(string: "fotolokashen://email-verified?token=test-token")!))

        wait(for: [verifiedChanged, tokenChanged], timeout: 0)
        XCTAssertTrue(sut.emailVerified)
        XCTAssertEqual(sut.autoLoginToken, "test-token")
    }

    func testPasswordResetCompletionIsObservable() {
        let changed = expectation(description: "Password-reset completion is observed")
        withObservationTracking {
            _ = sut.passwordResetComplete
        } onChange: {
            changed.fulfill()
        }

        XCTAssertTrue(sut.handleURL(URL(string: "fotolokashen://password-reset-complete")!))

        wait(for: [changed], timeout: 0)
        XCTAssertTrue(sut.passwordResetComplete)
    }

    func testLocationCustomURLNavigatesToLocation() {
        let handled = sut.handleURL(URL(string: "fotolokashen://location/123")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(sut.pendingLocationId, 123)
    }

    func testNonNumericLocationCustomURLIsNotHandled() {
        let handled = sut.handleURL(URL(string: "fotolokashen://location/not-a-number")!)

        XCTAssertFalse(handled)
        XCTAssertNil(sut.pendingLocationId)
    }

    func testEmailVerifiedURLWithTokenStoresTokenAndMarksVerified() {
        let handled = sut.handleURL(
            URL(string: "fotolokashen://email-verified?token=one-time-token")!
        )

        XCTAssertTrue(handled)
        XCTAssertTrue(sut.emailVerified)
        XCTAssertEqual(sut.autoLoginToken, "one-time-token")
    }

    func testEmailVerifiedURLWithoutTokenStillMarksVerified() {
        let handled = sut.handleURL(URL(string: "fotolokashen://email-verified")!)

        XCTAssertTrue(handled)
        XCTAssertTrue(sut.emailVerified)
        XCTAssertNil(sut.autoLoginToken)
    }

    func testUniversalLinkFromExactHTTPSHostNavigatesToLocation() {
        let handled = sut.handleURL(URL(string: "https://fotolokashen.com/shared/123")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(sut.pendingLocationId, 123)
    }

    func testSpoofedUniversalLinkHostIsRejected() {
        let handled = sut.handleURL(
            URL(string: "https://fotolokashen.com.attacker.test/shared/1")!
        )

        XCTAssertFalse(handled)
        XCTAssertNil(sut.pendingLocationId)
    }

    func testUnapprovedUniversalLinkHostAndNonHTTPSURLAreRejected() {
        let subdomain = sut.handleURL(URL(string: "https://www.fotolokashen.com/shared/1")!)
        let insecure = sut.handleURL(URL(string: "http://fotolokashen.com/shared/2")!)

        XCTAssertFalse(subdomain)
        XCTAssertFalse(insecure)
        XCTAssertNil(sut.pendingLocationId)
    }

    func testOAuthCustomSchemeCallbackRemainsUnhandledForAuthService() {
        let handled = sut.handleURL(
            URL(string: "fotolokashen://oauth-callback?code=authorization-code")!
        )

        XCTAssertFalse(handled)
        XCTAssertNil(sut.pendingLocationId)
    }
}
