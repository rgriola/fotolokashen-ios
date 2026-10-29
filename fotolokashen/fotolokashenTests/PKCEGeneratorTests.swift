import CryptoKit
import XCTest
@testable import fotolokashen

final class PKCEGeneratorTests: XCTestCase {

    func testGeneratedVerifierAndChallengeMeetRFC7636EncodingRequirements() {
        let (verifier, challenge) = PKCEGenerator.generate()

        XCTAssertTrue((43...128).contains(verifier.utf8.count))
        XCTAssertTrue(verifier.utf8.allSatisfy(isVerifierByte))
        XCTAssertEqual(challenge.utf8.count, 43)
        XCTAssertTrue(challenge.utf8.allSatisfy(isBase64URLByte))
    }

    func testS256ChallengeMatchesRFC7636AppendixBKnownAnswer() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        // RFC 7636 Appendix B's S256 value.
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

        XCTAssertEqual(verifier.utf8.count, 43)
        XCTAssertEqual(PKCEGenerator.generateCodeChallenge(from: verifier), expectedChallenge)
    }

    func testOneThousandGeneratedVerifierAndChallengePairsAreUniqueAndValid() {
        var verifiers = Set<String>()
        var challenges = Set<String>()

        for _ in 0..<1_000 {
            let (verifier, challenge) = PKCEGenerator.generate()

            XCTAssertTrue((43...128).contains(verifier.utf8.count))
            XCTAssertTrue(verifier.utf8.allSatisfy(isVerifierByte))
            XCTAssertEqual(challenge.utf8.count, 43)
            XCTAssertTrue(challenge.utf8.allSatisfy(isBase64URLByte))
            XCTAssertEqual(challenge, s256Base64URL(verifier))
            verifiers.insert(verifier)
            challenges.insert(challenge)
        }

        XCTAssertEqual(verifiers.count, 1_000, "All generated verifiers must be unique")
        XCTAssertEqual(challenges.count, 1_000, "All generated challenges must be unique")
    }

    func testOAuthStateIsURLSafeUniqueAndDistinctFromPKCEValues() {
        var states = Set<String>()

        for _ in 0..<1_000 {
            let (verifier, challenge) = PKCEGenerator.generate()
            let state = PKCEGenerator.generateOAuthState()

            XCTAssertTrue(state.hasPrefix("oauth_"))
            XCTAssertEqual(state.utf8.count, 49)
            XCTAssertTrue(state.utf8.allSatisfy(isBase64URLByte))
            XCTAssertNotEqual(state, verifier)
            XCTAssertNotEqual(state, challenge)
            states.insert(state)
        }

        XCTAssertEqual(states.count, 1_000, "Every login attempt must receive a fresh state")
    }

    private func s256Base64URL(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func isVerifierByte(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) ||
        (97...122).contains(byte) ||
        (48...57).contains(byte) ||
        [45, 46, 95, 126].contains(byte) // - . _ ~
    }

    private func isBase64URLByte(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) ||
        (97...122).contains(byte) ||
        (48...57).contains(byte) ||
        byte == 45 || byte == 95 // - _
    }

}
