import XCTest
@testable import fotolokashen

nonisolated final class LoggingTests: XCTestCase {
    func testDebugPolicyHonorsConfigurationAndBuild() {
        XCTAssertFalse(Log.isDebugEnabled(configured: false))
        #if DEBUG
        XCTAssertTrue(Log.isDebugEnabled(configured: true))
        #else
        XCTAssertFalse(Log.isDebugEnabled(configured: true))
        #endif
    }

    func testDisabledDebugDoesNotEvaluateMessage() {
        var evaluated = false
        func message() -> String {
            evaluated = true
            return "debug event"
        }
        Log.debug(message(), enabled: false)
        XCTAssertFalse(evaluated)
    }

    func testReleaseDebugDoesNotEvaluateMessageEvenWhenEnabled() {
        #if !DEBUG
        var evaluated = false
        func message() -> String {
            evaluated = true
            return "debug event"
        }
        Log.debug(message(), enabled: true)
        XCTAssertFalse(evaluated)
        dlog("LoggingTests", message())
        XCTAssertFalse(evaluated)
        #endif
    }

    func testNetworkFailureClassification() {
        XCTAssertEqual(Log.failure(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(Log.failure(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(Log.failure(URLError(.timedOut)), .timedOut)
        XCTAssertEqual(Log.failure(URLError(.cannotConnectToHost)), .transport)
        XCTAssertEqual(Log.failure(CancellationError()), .cancelled)
        XCTAssertEqual(Log.failure(TaskTimeoutError()), .timedOut)
    }

    func testAPIFailureClassificationDoesNotExposeErrorText() {
        XCTAssertEqual(Log.failure(APIError.apiError("private server message", "private-code")), .rejected)
        XCTAssertEqual(Log.failure(APIError.unknownError(503)), .server)
        XCTAssertEqual(Log.failure(APIError.unknownError(400)), .rejected)
        XCTAssertEqual(Log.failure(APIError.unauthorized), .unauthorized)
        XCTAssertEqual(Log.failure(APIError.forbidden), .forbidden)
        XCTAssertEqual(Log.failure(APIError.notFound), .notFound)
        XCTAssertEqual(Log.failure(APIError.invalidResponse), .invalidResponse)
    }

    func testNestedDecodingErrorIsNotDescribed() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "private payload"))
        XCTAssertEqual(Log.failure(error), .decoding)
        XCTAssertEqual(Log.failure(APIError.decodingFailed(error)), .decoding)
        XCTAssertEqual(Log.failure(NSError(domain: "private-domain", code: 1)), .other)
    }
}
