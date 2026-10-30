import Foundation
import OSLog

nonisolated enum Log {
    static let subsystem = "com.fotolokashen.app"
    static let app = Logger(subsystem: subsystem, category: "App")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let photos = Logger(subsystem: subsystem, category: "Photos")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    static let locations = Logger(subsystem: subsystem, category: "Locations")
    static let deepLink = Logger(subsystem: subsystem, category: "DeepLink")

    enum Failure: String, Sendable {
        case cancelled, offline, timedOut, transport, decoding
        case unauthorized, forbidden, notFound, invalidResponse, server, rejected, other
    }

    // Never use localizedDescription, NSError.userInfo, or server error text in logs.
    static func failure(_ error: Error) -> Failure {
        if error is CancellationError { return .cancelled }
        if error is TaskTimeoutError { return .timedOut }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return .cancelled
            case .notConnectedToInternet: return .offline
            case .timedOut: return .timedOut
            default: return .transport
            }
        }
        if error is DecodingError { return .decoding }
        if let error = error as? APIError {
            switch error {
            case .unauthorized: return .unauthorized
            case .forbidden: return .forbidden
            case .notFound: return .notFound
            case .invalidResponse: return .invalidResponse
            case .decodingFailed: return .decoding
            case .apiError: return .rejected
            case .unknownError(let status): return status >= 500 ? .server : .rejected
            }
        }
        return .other
    }

    static func isDebugEnabled(configured: Bool) -> Bool {
        #if DEBUG
        return configured
        #else
        return false
        #endif
    }

    static var debugEnabled: Bool {
        #if DEBUG
        isDebugEnabled(configured: ConfigLoader.shared.enableDebugLogging)
        #else
        false
        #endif
    }

    static func debug(
        _ message: @autoclosure () -> String,
        logger: Logger = app,
        enabled: Bool? = nil
    ) {
        #if DEBUG
        guard enabled ?? debugEnabled else { return }
        let resolved = message()
        logger.debug("\(resolved, privacy: .private)")
        #endif
    }

    static func logger(forLegacyTag tag: String) -> Logger {
        switch tag {
        case "AuthService", "KeychainService", "PKCEGenerator": return auth
        case "APIClient", "NetworkMonitor": return network
        case "DataManager", "PersistentStoreRecovery": return persistence
        case "DeepLinkManager", "DeepLink": return deepLink
        case "PhotoUpload", "PhotoUploadQueue", "PhotoPipeline", "ImageCompressor",
             "PhotoPicker", "PhotoPickerViewModel", "CameraService", "CameraSession", "Camera": return photos
        case "LocationService", "LocationRepository", "LocationStore", "GeocodingService",
             "AppleGeocoding", "GoogleGeocoding", "SyncService", "Sync",
             "LocationManager", "PlacesService", "MapPlaceSearchService", "MapView",
             "CreateLocation", "CreateLocationViewModel", "EditLocationViewModel",
             "LocationDetailViewModel", "LocationListViewModel", "LocationGroupService": return locations
        default: return app
        }
    }
}

/// Compatibility bridge: private DEBUG breadcrumbs only; never supply sensitive values.
nonisolated public func dlog(_ tag: String, _ message: @autoclosure () -> String) {
    Log.debug("[\(tag)] \(message())", logger: Log.logger(forLegacyTag: tag))
}
