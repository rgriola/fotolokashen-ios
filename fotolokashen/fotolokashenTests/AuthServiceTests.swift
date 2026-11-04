import Observation
import XCTest
@testable import fotolokashen

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var sut: AuthService!
    
    override func setUp() async throws {
        try await super.setUp()
        try KeychainService.shared.clearTokens()
        sut = AuthService()
    }
    
    override func tearDown() async throws {
        sut = nil
        try KeychainService.shared.clearTokens()
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialAuthState() {
        // Then
        XCTAssertFalse(sut.isAuthenticated, "Should not be authenticated initially without tokens")
        XCTAssertNil(sut.currentUser, "Should have no current user initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
    }

    func testAuthenticationAndCurrentUserAreObservable() throws {
        let authChanged = expectation(description: "Authentication state is observed")
        let userChanged = expectation(description: "Current user is observed")
        withObservationTracking {
            _ = sut.isAuthenticated
        } onChange: {
            authChanged.fulfill()
        }
        withObservationTracking {
            _ = sut.currentUser
        } onChange: {
            userChanged.fulfill()
        }

        sut.currentUser = try JSONDecoder().decode(
            User.self,
            from: Data(#"{"id":1,"email":"test@example.com","username":"test"}"#.utf8)
        )
        sut.isAuthenticated = true

        wait(for: [authChanged, userChanged], timeout: 0)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.currentUser?.id, 1)
    }

    func testLoadingAndErrorAreObservable() {
        let loadingChanged = expectation(description: "Authentication loading state is observed")
        let errorChanged = expectation(description: "Authentication error is observed")
        withObservationTracking {
            _ = sut.isLoading
        } onChange: {
            loadingChanged.fulfill()
        }
        withObservationTracking {
            _ = sut.errorMessage
        } onChange: {
            errorChanged.fulfill()
        }

        sut.isLoading = true
        sut.errorMessage = "Unable to sign in"

        wait(for: [loadingChanged, errorChanged], timeout: 0)
        XCTAssertTrue(sut.isLoading)
        XCTAssertEqual(sut.errorMessage, "Unable to sign in")
    }

    func testVerificationAndPasswordResetPromptsAreObservable() {
        let verificationChanged = expectation(description: "Verification prompt is observed")
        let resetChanged = expectation(description: "Password-reset prompt is observed")
        withObservationTracking {
            _ = sut.awaitingVerification
        } onChange: {
            verificationChanged.fulfill()
        }
        withObservationTracking {
            _ = sut.awaitingPasswordReset
        } onChange: {
            resetChanged.fulfill()
        }

        sut.awaitingVerification = true
        sut.awaitingPasswordReset = true

        wait(for: [verificationChanged, resetChanged], timeout: 0)
        XCTAssertTrue(sut.awaitingVerification)
        XCTAssertTrue(sut.awaitingPasswordReset)
    }
    
    // MARK: - Logout Tests
    
    func testLogoutClearsState() async {
        sut.isAuthenticated = true
        let changed = expectation(description: "Logout authentication transition is observed")
        let waiter = ObservationWaiter(sut!, \.isAuthenticated, fulfilling: changed, where: { !$0 })

        // When
        await sut.logout()
        await fulfillment(of: [changed], timeout: 1)
        waiter.cancel()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated, "Should not be authenticated after logout")
        XCTAssertNil(sut.currentUser, "Current user should be nil after logout")
    }
}
