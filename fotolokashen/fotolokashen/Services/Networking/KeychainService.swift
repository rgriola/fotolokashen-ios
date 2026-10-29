import Foundation
import Security

/// Secure storage for OAuth credentials. KeychainAccess used this same generic
/// password service/account identity, with no explicit access group, and
/// synchronizable disabled. Keeping that identity lets SecItem update existing
/// credentials in place when the app is upgraded.
final class KeychainService {

    static let shared = KeychainService()

    private enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let tokenExpiry = "token_expiry"
        static let userID = "user_id"
        static let all = [accessToken, refreshToken, tokenExpiry, userID]
    }

    static let serviceName = "com.fotolokashen.ios"
    private static let migratedAccessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private let store: KeychainItemStore
    private let lock = NSRecursiveLock()
    private var migrationVerified = false

    private init() {
        store = SecItemKeychainStore(service: Self.serviceName)
    }

    /// Injectable store keeps migration and failure behavior deterministic in tests.
    init(store: KeychainItemStore) {
        self.store = store
    }

    // MARK: - Token Storage

    func saveToken(_ token: OAuthToken) throws {
        try lock.performLocked {
            try migrateLegacyItemsIfNeeded()
            try store.set(Data(token.accessToken.utf8), account: Keys.accessToken, accessibility: Self.migratedAccessibility)
            try store.set(Data(token.refreshToken.utf8), account: Keys.refreshToken, accessibility: Self.migratedAccessibility)
            try store.set(Data(token.expiresAt.timeIntervalSince1970.description.utf8), account: Keys.tokenExpiry, accessibility: Self.migratedAccessibility)
            try store.set(Data(String(token.user.id).utf8), account: Keys.userID, accessibility: Self.migratedAccessibility)
        }

        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            dlog("KeychainService", "Token saved")
        }
        #endif
    }

    func getAccessToken() throws -> String? {
        try readString(for: Keys.accessToken)
    }

    /// Rotate access token while leaving refresh token and user id untouched.
    func updateAccessToken(_ accessToken: String, expiresAt: Date) throws {
        try lock.performLocked {
            try migrateLegacyItemsIfNeeded()
            try store.set(Data(accessToken.utf8), account: Keys.accessToken, accessibility: Self.migratedAccessibility)
            try store.set(Data(expiresAt.timeIntervalSince1970.description.utf8), account: Keys.tokenExpiry, accessibility: Self.migratedAccessibility)
        }
    }

    func getRefreshToken() throws -> String? {
        try readString(for: Keys.refreshToken)
    }

    func getTokenExpiry() throws -> Date? {
        guard let value = try readString(for: Keys.tokenExpiry),
              let timestamp = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getUserID() throws -> Int? {
        guard let value = try readString(for: Keys.userID) else { return nil }
        return Int(value)
    }

    func isTokenExpired() throws -> Bool {
        guard let expiry = try getTokenExpiry() else { return true }
        return Date() >= expiry
    }

    func needsRefresh() throws -> Bool {
        guard let expiry = try getTokenExpiry() else { return true }
        return Date().addingTimeInterval(300) >= expiry
    }

    func clearTokens() throws {
        try lock.performLocked {
            // Do not remove any credential if migration/read has failed.
            try migrateLegacyItemsIfNeeded()
            for account in Keys.all {
                try store.remove(account: account)
            }
        }

        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            dlog("KeychainService", "Tokens cleared")
        }
        #endif
    }

    func hasValidTokens() throws -> Bool {
        guard try getAccessToken() != nil,
              try getRefreshToken() != nil else {
            return false
        }
        let expired = try isTokenExpired()
        return !expired
    }

    private func readString(for account: String) throws -> String? {
        try lock.performLocked {
            try migrateLegacyItemsIfNeeded()
            guard let data = try store.read(account: account) else { return nil }
            guard let value = String(data: data, encoding: .utf8) else {
                throw KeychainServiceError.invalidCredentialEncoding
            }
            return value
        }
    }

    /// KeychainAccess and this implementation address the same items. Upgrade
    /// their accessibility in place: no legacy credential is deleted, and the
    /// original bytes are verified after every update. All reads complete before
    /// any writes begin; any failure stops the migration and is propagated.
    private func migrateLegacyItemsIfNeeded() throws {
        guard !migrationVerified else { return }

        var credentials: [(account: String, data: Data)] = []
        for account in Keys.all {
            if let data = try store.read(account: account) {
                credentials.append((account, data))
            }
        }
        defer {
            for index in credentials.indices {
                let count = credentials[index].data.count
                credentials[index].data.resetBytes(in: 0..<count)
            }
        }

        for credential in credentials {
            try store.set(
                credential.data,
                account: credential.account,
                accessibility: Self.migratedAccessibility
            )
        }

        for credential in credentials {
            guard let verifiedData = try store.read(account: credential.account),
                  verifiedData == credential.data else {
                throw KeychainServiceError.migrationVerificationFailed
            }
        }
        migrationVerified = true
    }
}

protocol KeychainAccessFailure: Error {}

enum KeychainServiceError: LocalizedError, KeychainAccessFailure {
    case invalidCredentialEncoding
    case migrationVerificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredentialEncoding:
            return "A stored credential could not be decoded."
        case .migrationVerificationFailed:
            return "Stored credentials could not be verified after migration."
        }
    }
}

protocol KeychainItemStore {
    func read(account: String) throws -> Data?
    func set(_ data: Data, account: String, accessibility: CFString) throws
    func remove(account: String) throws
}

struct SecItemKeychainStore: KeychainItemStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) throws -> Data? {
        var query = itemQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecItemKeychainError(status: status) }
        guard let data = result as? Data else { throw KeychainServiceError.migrationVerificationFailed }
        return data
    }

    func set(_ data: Data, account: String, accessibility: CFString) throws {
        let query = itemQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw SecItemKeychainError(status: status) }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw SecItemKeychainError(status: addStatus) }
    }

    func remove(account: String) throws {
        let status = SecItemDelete(itemQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecItemKeychainError(status: status)
        }
    }

    private func itemQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}

private struct SecItemKeychainError: LocalizedError, KeychainAccessFailure {
    let status: OSStatus
    var errorDescription: String? {
        "Keychain operation failed (OSStatus \(status))."
    }
}

private extension NSRecursiveLock {
    func performLocked<T>(_ operation: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try operation()
    }
}
