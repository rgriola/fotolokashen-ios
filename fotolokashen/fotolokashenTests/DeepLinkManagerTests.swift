import XCTest
@testable import fotolokashen

@MainActor
final class DeepLinkManagerTests: XCTestCase {

    private let sut = DeepLinkManager.shared

    override func setUp() {
        super.setUp()
        sut.clearPendingNavigation()
        sut.autoLoginToken = nil
        sut.emailVerified = false
        sut.passwordResetComplete = false
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
