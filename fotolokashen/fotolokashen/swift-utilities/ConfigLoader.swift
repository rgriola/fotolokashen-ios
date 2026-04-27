import Foundation

/// Configuration loader for reading values from Config.plist
/// Provides type-safe access to app configuration
class ConfigLoader {
    
    // MARK: - Singleton
    
    static let shared = ConfigLoader()
    
    // MARK: - Properties
    
    private let config: [String: Any]
    
    // MARK: - Initialization
    
    // REVIEW: fatalError() on missing Config.plist is too aggressive for production.
    // Consider logging the error and falling back to default values, or using a
    // @Published var configError to surface this in the UI gracefully.
    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Config.plist not found or invalid format")
        }
        self.config = dict
    }
    
    /// Backend URL, resolved in priority order:
    /// 1. Info.plist `BackendBaseURL` (injected from Debug/Release.xcconfig)
    /// 2. Config.plist `backendBaseURL` (static fallback)
    /// 3. Hardcoded default
    var backendBaseURL: String {
        // Prefer xcconfig-injected value from Info.plist
        if let infoPlistURL = Bundle.main.infoDictionary?["BackendBaseURL"] as? String,
           !infoPlistURL.isEmpty,
           infoPlistURL != "$(BACKEND_BASE_URL)" { // Not substituted = variable missing
            return infoPlistURL
        }
        // Fall back to Config.plist
        return getString(forKey: "backendBaseURL") ?? "https://fotolokashen.com"
    }
    
    var backendURL: URL {
        guard let url = URL(string: backendBaseURL) else {
            fatalError("Invalid backend URL: \(backendBaseURL)")
        }
        return url
    }
    
    // MARK: - Google Maps
    
    var googleMapsAPIKey: String {
        getString(forKey: "googleMapsAPIKey") ?? ""
    }
    
    // MARK: - ImageKit
    
    var imagekitPublicKey: String {
        getString(forKey: "imagekitPublicKey") ?? ""
    }
    
    var imagekitUrlEndpoint: String {
        getString(forKey: "imagekitUrlEndpoint") ?? "https://ik.imagekit.io/rgriola"
    }
    
    var imagekitURL: URL {
        guard let url = URL(string: imagekitUrlEndpoint) else {
            fatalError("Invalid ImageKit URL: \(imagekitUrlEndpoint)")
        }
        return url
    }
    
    // MARK: - OAuth Configuration
    
    var oauthClientId: String {
        getOAuthValue(forKey: "clientId") ?? "fotolokashen-ios"
    }
    
    var oauthRedirectUri: String {
        getOAuthValue(forKey: "redirectUri") ?? "fotolokashen://oauth-callback"
    }
    
    var oauthScopes: [String] {
        getOAuthValue(forKey: "scopes") ?? ["read", "write"]
    }
    
    var oauthScopesString: String {
        oauthScopes.joined(separator: " ")
    }
    
    // MARK: - Image Compression
    
    var compressionTargetBytes: Int {
        getCompressionValue(forKey: "uploadTargetBytes") ?? 1_500_000
    }
    
    var compressionQualityStart: CGFloat {
        getCompressionValue(forKey: "compressionQualityStart") ?? 0.9
    }
    
    var compressionQualityFloor: CGFloat {
        getCompressionValue(forKey: "compressionQualityFloor") ?? 0.4
    }
    
    var compressionMaxDimension: CGFloat {
        CGFloat(getCompressionValue(forKey: "compressionMaxDimension") ?? 3000)
    }
    
    var maxPhotosPerLocation: Int {
        getCompressionValue(forKey: "maxPhotosPerLocation") ?? 20
    }
    
    /// Get image compression configuration
    var imageCompressionConfig: ImageCompressor.Config {
        ImageCompressor.Config(
            targetBytes: compressionTargetBytes,
            qualityStart: compressionQualityStart,
            qualityFloor: compressionQualityFloor,
            maxDimension: compressionMaxDimension
        )
    }
    
    // MARK: - Feature Flags
    
    var enableOfflineMode: Bool {
        getFeatureFlag(forKey: "enableOfflineMode") ?? true
    }
    
    var enableDebugLogging: Bool {
        getFeatureFlag(forKey: "enableDebugLogging") ?? false
    }
    
    // MARK: - Helper Methods
    
    private func getString(forKey key: String) -> String? {
        config[key] as? String
    }
    
    private func getInt(forKey key: String) -> Int? {
        config[key] as? Int
    }
    
    private func getBool(forKey key: String) -> Bool? {
        config[key] as? Bool
    }
    
    private func getDouble(forKey key: String) -> Double? {
        config[key] as? Double
    }
    
    private func getOAuthValue<T>(forKey key: String) -> T? {
        guard let oauth = config["oauth"] as? [String: Any] else {
            return nil
        }
        return oauth[key] as? T
    }
    
    private func getCompressionValue<T>(forKey key: String) -> T? {
        guard let compression = config["imageCompression"] as? [String: Any] else {
            return nil
        }
        return compression[key] as? T
    }
    
    private func getFeatureFlag(forKey key: String) -> Bool? {
        guard let features = config["features"] as? [String: Any] else {
            return nil
        }
        return features[key] as? Bool
    }
}

// MARK: - Convenience Extensions

extension ConfigLoader {
    /// Print all configuration values (for debugging only)
    func printConfiguration() {
        #if DEBUG
        print("=== fotolokashen Configuration ===")
        print("Backend URL: \(backendBaseURL)")
        print("OAuth Client ID: \(oauthClientId)")
        print("OAuth Redirect URI: \(oauthRedirectUri)")
        print("OAuth Scopes: \(oauthScopesString)")
        print("ImageKit Endpoint: \(imagekitUrlEndpoint)")
        print("Compression Target: \(ByteCountFormatter.string(fromByteCount: Int64(compressionTargetBytes), countStyle: .file))")
        print("Max Dimension: \(Int(compressionMaxDimension))px")
        print("Offline Mode: \(enableOfflineMode ? "Enabled" : "Disabled")")
        print("Debug Logging: \(enableDebugLogging ? "Enabled" : "Disabled")")
        print("================================")
        #endif
    }
}

// MARK: - Usage Example
/*
 // Access configuration values
 let config = ConfigLoader.shared
 
 print("Backend URL: \(config.backendBaseURL)")
 print("OAuth Client ID: \(config.oauthClientId)")
 print("Google Maps Key: \(config.googleMapsAPIKey)")
 
 // Get image compression config
 let compressionConfig = config.imageCompressionConfig
 let compressedData = ImageCompressor.compress(image, config: compressionConfig)
 
 // Check feature flags
 if config.enableDebugLogging {
     print("Debug mode enabled")
 }
 
 // Print all configuration (for debugging)
 config.printConfiguration()
 */
