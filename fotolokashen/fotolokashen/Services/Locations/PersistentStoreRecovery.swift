import Foundation

struct StoreOpenResult<Store> {
    let store: Store
    let quarantinedStoreURL: URL?
}

struct StoreRecoveryFailure: LocalizedError {
    let initialError: Error
    let retryError: Error
    let quarantinedStoreURL: URL?

    var errorDescription: String? {
        "The local store could not be opened, and creating a fresh store also failed. "
            + "Initial error: \(initialError.localizedDescription). "
            + "Retry error: \(retryError.localizedDescription)."
    }
}

/// Retries store creation only after the first creation attempt has thrown.
enum PersistentStoreRecovery {
    static func open<Store>(
        createStore: () throws -> Store,
        quarantineStore: () throws -> URL?
    ) throws -> StoreOpenResult<Store> {
        do {
            return StoreOpenResult(store: try createStore(), quarantinedStoreURL: nil)
        } catch let initialError {
            let quarantineURL = try quarantineStore()

            do {
                return StoreOpenResult(
                    store: try createStore(),
                    quarantinedStoreURL: quarantineURL
                )
            } catch let retryError {
                throw StoreRecoveryFailure(
                    initialError: initialError,
                    retryError: retryError,
                    quarantinedStoreURL: quarantineURL
                )
            }
        }
    }

    /// Moves a SQLite store and its sidecars into a unique, recoverable directory.
    /// If any move fails, already-moved files are rolled back and no retry should occur.
    @discardableResult
    static func quarantineSQLiteStore(
        at storeURL: URL,
        fileManager: FileManager = .default,
        recoveryRootURL: URL? = nil
    ) throws -> URL? {
        let suffixes = ["", "-wal", "-shm", "-journal"]
        let filesToMove = suffixes
            .map { suffix in
                (source: URL(fileURLWithPath: storeURL.path + suffix),
                 name: storeURL.lastPathComponent + suffix)
            }
            .filter { fileManager.fileExists(atPath: $0.source.path) }

        guard !filesToMove.isEmpty else { return nil }

        let recoveryRoot = recoveryRootURL
            ?? storeURL.deletingLastPathComponent()
                .appendingPathComponent("SwiftDataRecovery", isDirectory: true)
        try fileManager.createDirectory(
            at: recoveryRoot,
            withIntermediateDirectories: true
        )

        let quarantineURL = recoveryRoot.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: quarantineURL,
            withIntermediateDirectories: false
        )

        var movedFiles: [(source: URL, destination: URL)] = []
        do {
            for file in filesToMove {
                let destination = quarantineURL.appendingPathComponent(file.name)
                try fileManager.moveItem(at: file.source, to: destination)
                movedFiles.append((source: file.source, destination: destination))
            }
        } catch {
            var rollbackSucceeded = true
            for file in movedFiles.reversed() {
                do {
                    try fileManager.moveItem(at: file.destination, to: file.source)
                } catch {
                    rollbackSucceeded = false
                }
            }
            if rollbackSucceeded {
                try? fileManager.removeItem(at: quarantineURL)
            }
            throw error
        }

        return quarantineURL
    }
}
