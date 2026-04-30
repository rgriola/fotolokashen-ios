import XCTest
@testable import fotolokashen

/// Phase 4d — `APIClient` HTTP/decoding/error-mapping coverage via a
/// `URLProtocol` stub injected into a custom-config session.
///
/// All requests use `authenticated: false` so the Keychain isn't touched.
final class APIClientTests: XCTestCase {

    private var client: APIClient!
    private let baseURL = URL(string: "https://test.fotolokashen.com")!

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        client = APIClient(session: session, baseURL: baseURL)
    }

    override func tearDown() {
        URLProtocolStub.reset()
        client = nil
        super.tearDown()
    }

    // MARK: - Test Models

    private struct Echo: Codable, Equatable {
        let id: Int
        let name: String
    }

    private struct EmptyBody: Encodable {}

    // MARK: - Happy Path

    func testGetDecodesResponseBody() async throws {
        URLProtocolStub.stub(
            json: #"{"id":42,"name":"hello"}"#,
            statusCode: 200
        )
        let result: Echo = try await client.get("/api/test", authenticated: false)
        XCTAssertEqual(result, Echo(id: 42, name: "hello"))
    }

    func testGetBuildsCorrectURL() async throws {
        URLProtocolStub.stub(json: #"{"id":1,"name":"x"}"#, statusCode: 200)
        let _: Echo = try await client.get("/api/locations", authenticated: false)

        let request = URLProtocolStub.lastRequest
        XCTAssertEqual(request?.url?.absoluteString, "https://test.fotolokashen.com/api/locations")
        XCTAssertEqual(request?.httpMethod, "GET")
    }

    func testPostSendsJSONBody() async throws {
        URLProtocolStub.stub(json: #"{"id":7,"name":"posted"}"#, statusCode: 201)
        let body = Echo(id: 0, name: "input")
        let result: Echo = try await client.post("/api/items", body: body, authenticated: false)

        XCTAssertEqual(result.name, "posted")
        XCTAssertEqual(URLProtocolStub.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(URLProtocolStub.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = URLProtocolStub.lastRequestBody
        XCTAssertNotNil(bodyData)
        let decoded = try JSONDecoder().decode(Echo.self, from: bodyData!)
        XCTAssertEqual(decoded, body)
    }

    func testPathWithoutLeadingSlashStillWorks() async throws {
        URLProtocolStub.stub(json: #"{"id":1,"name":"x"}"#, statusCode: 200)
        let _: Echo = try await client.get("api/test", authenticated: false)
        XCTAssertEqual(URLProtocolStub.lastRequest?.url?.absoluteString,
                       "https://test.fotolokashen.com/api/test")
    }

    // MARK: - Error Mapping

    func testDecodeFailureMapsToDecodingFailed() async {
        URLProtocolStub.stub(json: #"{"unexpected":true}"#, statusCode: 200)
        do {
            let _: Echo = try await client.get("/api/test", authenticated: false)
            XCTFail("Expected decoding failure")
        } catch let error as APIError {
            guard case .decodingFailed = error else {
                XCTFail("Expected .decodingFailed, got \(error)")
                return
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test403MapsToForbidden() async {
        URLProtocolStub.stub(json: "{}", statusCode: 403)
        await assertThrows(APIError.forbidden) {
            let _: Echo = try await self.client.get("/api/test", authenticated: false)
        }
    }

    func test404MapsToNotFound() async {
        URLProtocolStub.stub(json: "{}", statusCode: 404)
        await assertThrows(APIError.notFound) {
            let _: Echo = try await self.client.get("/api/test", authenticated: false)
        }
    }

    func test400WithErrorBodyMapsToAPIError() async {
        URLProtocolStub.stub(
            json: #"{"error":"invalid input","code":"VALIDATION_FAILED"}"#,
            statusCode: 400
        )
        do {
            let _: Echo = try await client.get("/api/test", authenticated: false)
            XCTFail("Expected APIError")
        } catch APIError.apiError(let message, let code) {
            XCTAssertEqual(message, "invalid input")
            XCTAssertEqual(code, "VALIDATION_FAILED")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test500WithUnparseableBodyMapsToUnknownError() async {
        URLProtocolStub.stub(json: "<html>oops</html>", statusCode: 500)
        do {
            let _: Echo = try await client.get("/api/test", authenticated: false)
            XCTFail("Expected unknownError")
        } catch APIError.unknownError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - 401 Broadcast

    func test401PostsAuthSessionInvalidatedNotification() async {
        URLProtocolStub.stub(json: #"{"error":"unauth"}"#, statusCode: 401)

        let expectation = XCTNSNotificationExpectation(name: .authSessionInvalidated)
        expectation.expectedFulfillmentCount = 1

        await assertThrows(APIError.unauthorized) {
            let _: Echo = try await self.client.get("/api/test", authenticated: false)
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - Helpers

    private func assertThrows(_ expected: APIError, _ block: () async throws -> Void) async {
        do {
            try await block()
            XCTFail("Expected \(expected) to be thrown")
        } catch let error as APIError {
            // APIError is not Equatable — compare by case.
            XCTAssertEqual(String(describing: error).split(separator: "(").first,
                           String(describing: expected).split(separator: "(").first,
                           "Expected case \(expected), got \(error)")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - URLProtocolStub

/// In-memory URLProtocol that returns a canned response for every request.
/// Records the most recent request + body for assertions.
final class URLProtocolStub: URLProtocol {

    private struct Response {
        let data: Data
        let statusCode: Int
    }

    private static let lock = NSLock()
    private static var queued: Response?
    private static var _lastRequest: URLRequest?
    private static var _lastBody: Data?

    static func stub(json: String, statusCode: Int) {
        lock.lock(); defer { lock.unlock() }
        queued = Response(data: Data(json.utf8), statusCode: statusCode)
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        queued = nil
        _lastRequest = nil
        _lastBody = nil
    }

    static var lastRequest: URLRequest? {
        lock.lock(); defer { lock.unlock() }
        return _lastRequest
    }

    static var lastRequestBody: Data? {
        lock.lock(); defer { lock.unlock() }
        return _lastBody
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLProtocol clones the request body into a stream when using
        // URLSessionConfiguration; capture either the body or stream contents.
        let bodyData: Data? = {
            if let data = request.httpBody { return data }
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                var collected = Data()
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: buffer.count)
                    if read <= 0 { break }
                    collected.append(buffer, count: read)
                }
                return collected.isEmpty ? nil : collected
            }
            return nil
        }()

        URLProtocolStub.lock.lock()
        URLProtocolStub._lastRequest = request
        URLProtocolStub._lastBody = bodyData
        let queued = URLProtocolStub.queued
        URLProtocolStub.lock.unlock()

        guard let response = queued, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
