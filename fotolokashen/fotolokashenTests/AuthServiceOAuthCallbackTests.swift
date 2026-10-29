import XCTest
import AuthenticationServices
@testable import fotolokashen

/// Regression coverage for the iOS "Token Exchange Failed" bug (Oct 2026):
/// `ASWebAuthenticationSession`'s completion handler and the app's
/// `.onOpenURL` fallback can both fire `AuthService.handleCallback(url:)`
/// for the *same* OAuth redirect. Before the fix, this sent two concurrent
/// `POST /api/auth/oauth/token` requests for the same single-use
/// authorization code, racing the server and surfacing as a login failure.
@MainActor
final class AuthServiceOAuthCallbackTests: XCTestCase {

    private let callbackURL = URL(string: "fotolokashen://oauth-callback?code=test-auth-code")!
    private let baseURL = URL(string: "https://test.fotolokashen.com")!

    override func setUp() {
        super.setUp()
        CountingTokenExchangeStub.reset()
        // Defensive: a stale refresh token left in the real Keychain by an
        // unrelated test would make AuthService.init()'s checkAuthStatus()
        // fire its own background network request, polluting the request
        // count this suite asserts on.
        try? KeychainService.shared.clearTokens()
    }

    override func tearDownWithError() throws {
        try KeychainService.shared.clearTokens()
        try super.tearDownWithError()
    }

    /// Builds an `APIClient` whose session routes every request through
    /// `CountingTokenExchangeStub` instead of the real network, mirroring
    /// the injection pattern already used by `APIClientTests`.
    private func makeStubbedAPIClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CountingTokenExchangeStub.self]
        let session = URLSession(configuration: config)
        return APIClient(session: session, baseURL: baseURL)
    }

    func testDuplicateCallbackForSameCodeSendsOnlyOneTokenRequest() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        // Simulate the real-world race: both delivery paths invoke
        // handleCallback for the same redirect at roughly the same time.
        async let first: Void = sut.handleCallback(url: callbackURL)
        async let second: Void = sut.handleCallback(url: callbackURL)
        _ = await (first, second)

        XCTAssertEqual(
            CountingTokenExchangeStub.requestCount, 1,
            "A duplicate OAuth callback for the same code must not trigger a second token request"
        )
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertEqual(sut.currentUser?.id, 1)
        XCTAssertNil(sut.errorMessage)
    }

    /// The in-flight guard alone does not cover a duplicate that arrives
    /// *after* the first exchange finished (e.g. `onOpenURL` firing once the
    /// token round trip already completed). Without the completed-code memo
    /// this re-entered the exchange, failed on the cleared PKCE verifier, and
    /// showed a login error to an already-authenticated user.
    func testLateDuplicateCallbackForSameCodeIsIgnored() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        await sut.handleCallback(url: callbackURL)
        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 1)
        XCTAssertNil(sut.errorMessage)

        // Second delivery path for the same redirect, now that the first
        // exchange has fully completed.
        await sut.handleCallback(url: callbackURL)

        XCTAssertEqual(
            CountingTokenExchangeStub.requestCount, 1,
            "A late duplicate OAuth callback must not trigger a second token request"
        )
        XCTAssertNil(
            sut.errorMessage,
            "A late duplicate OAuth callback must not surface an error to a signed-in user"
        )
        XCTAssertTrue(sut.isAuthenticated)
    }

    func testSequentialCallbacksForDifferentCodesEachSendARequest() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        await sut.handleCallback(url: callbackURL)
        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 1)

        // A later, independent login (new code, new verifier) must not be
        // suppressed by the earlier call's now-finished in-flight guard.
        sut.debugSeedCodeVerifierForTesting("another-code-verifier")
        let secondURL = URL(string: "fotolokashen://oauth-callback?code=another-auth-code")!
        await sut.handleCallback(url: secondURL)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 2)
    }

    func testMissingCodeVerifierSurfacesAnErrorWithoutCrashing() async throws {
        // No debugSeedCodeVerifierForTesting call — simulates a callback
        // arriving with no PKCE state (e.g. after a process relaunch).
        let sut = AuthService(apiClient: makeStubbedAPIClient())

        await sut.handleCallback(url: callbackURL)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 0)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - S-2: externally delivered OAuth callbacks

    func testExternalCallbackAfterCancelledLoginMakesNoNetworkCall() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        await sut.handleWebAuthSessionCompletion(
            callbackURL: nil,
            error: ASWebAuthenticationSessionError(.canceledLogin)
        )
        let crafted = URL(string: "fotolokashen://oauth-callback?code=attacker-code")!
        await sut.handleExternalCallback(url: crafted)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 0)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.errorMessage, "A dropped external callback must not surface UI")
    }

    func testExternalCallbackAfterFailedSessionMakesNoNetworkCall() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        await sut.handleWebAuthSessionCompletion(
            callbackURL: nil,
            error: ASWebAuthenticationSessionError(.presentationContextInvalid)
        )
        await sut.handleExternalCallback(url: callbackURL)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 0)
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testExternalCallbackWithNoLoginInProgressIsIgnored() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())

        await sut.handleExternalCallback(url: callbackURL)
        let universalLink = URL(string: "https://fotolokashen.com/app/auth-callback?code=attacker-code")!
        await sut.handleExternalCallback(url: universalLink)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 0)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.errorMessage)
    }

    func testExternalCallbackAfterCompletedLoginIsIgnored() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        await sut.handleWebAuthSessionCompletion(callbackURL: callbackURL, error: nil)
        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 1)

        let crafted = URL(string: "fotolokashen://oauth-callback?code=attacker-code")!
        await sut.handleExternalCallback(url: crafted)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 1)
        XCTAssertNil(sut.errorMessage)
    }

    /// The `.onOpenURL` fallback must keep working while a login is active.
    func testExternalCallbackDuringActiveLoginIsExchangedOnce() async throws {
        let sut = AuthService(apiClient: makeStubbedAPIClient())
        sut.debugSeedCodeVerifierForTesting("test-code-verifier")

        async let external: Void = sut.handleExternalCallback(url: callbackURL)
        async let session: Void = sut.handleWebAuthSessionCompletion(callbackURL: callbackURL, error: nil)
        _ = await (external, session)

        XCTAssertEqual(CountingTokenExchangeStub.requestCount, 1)
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertNil(sut.errorMessage)
    }
}

// MARK: - CountingTokenExchangeStub

/// In-memory `URLProtocol` stub that returns a canned successful token
/// response for `/api/auth/oauth/token`, while counting how many requests
/// actually reached the network layer. Injected into a dedicated
/// `URLSession` per test via `APIClient(session:baseURL:)` — no global
/// `URLProtocol.registerClass` needed.
final class CountingTokenExchangeStub: URLProtocol {

    private static let lock = NSLock()
    private static var _requestCount = 0

    static var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _requestCount
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        CountingTokenExchangeStub.lock.lock()
        CountingTokenExchangeStub._requestCount += 1
        CountingTokenExchangeStub.lock.unlock()

        let json = """
        {
          "access_token": "stub-access-token",
          "refresh_token": "stub-refresh-token",
          "token_type": "Bearer",
          "expires_in": 604800,
          "scope": "read write",
          "user": { "id": 1, "email": "user@example.com", "username": "testuser" }
        }
        """

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
