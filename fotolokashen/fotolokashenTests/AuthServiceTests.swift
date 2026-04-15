import XCTest
@testable import fotolokashen

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var sut: AuthService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = AuthService()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialAuthState() {
        // Then
        XCTAssertFalse(sut.isAuthenticated, "Should not be authenticated initially without tokens")
        XCTAssertNil(sut.currentUser, "Should have no current user initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
    }
    
    // MARK: - Logout Tests
    
    func testLogoutClearsState() async {
        // When
        await sut.logout()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated, "Should not be authenticated after logout")
        XCTAssertNil(sut.currentUser, "Current user should be nil after logout")
    }
}
