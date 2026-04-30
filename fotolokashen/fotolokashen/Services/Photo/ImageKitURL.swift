import Foundation

/// Centralized ImageKit URL builder with predefined size variants.
/// Matches the web's `getPhotoUrl()` helper for consistency.
enum ImageVariant: String {
    case thumbnail   // List rows, small cells (120×120)
    case card        // Card previews (400×300)
    case gallery     // Detail view hero (800×600)
    case full        // Full-screen lightbox (1600px)
    case avatar      // Profile avatars (128×128)
    case avatarSmall // Compact avatars (48×48)
    case banner      // Profile banners (800×300)
}

enum ImageKitURL {
    static let baseURL = "https://ik.imagekit.io/rgriola"

    private static let transforms: [ImageVariant: String] = [
        .thumbnail:   "w-120,h-120,c-at_max,fo-auto,q-80",
        .card:        "w-400,h-300,c-at_max,fo-auto,q-80",
        .gallery:     "w-800,h-600,c-at_max,fo-auto,q-85",
        .full:        "w-1600,fo-auto,q-90",
        .avatar:      "w-128,h-128,c-at_max,fo-auto,q-80",
        .avatarSmall: "w-48,h-48,c-at_max,fo-auto,q-80",
        .banner:      "w-800,h-300,c-at_max,fo-auto,q-80",
    ]

    /// Build an optimized ImageKit URL for the given file path and variant.
    /// - Parameters:
    ///   - path: ImageKit file path (e.g., "/production/locations/123/photo.jpg")
    ///   - variant: Size preset matching usage context
    /// - Returns: Optimized URL with transforms applied, or nil if invalid
    static func url(for path: String, variant: ImageVariant) -> URL? {
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let transform = transforms[variant] else { return nil }
        return URL(string: "\(baseURL)\(cleanPath)?tr=\(transform)")
    }

    /// Build optimized URL from a full ImageKit URL string (already has base).
    /// - Parameters:
    ///   - fullUrl: Complete ImageKit URL string
    ///   - variant: Size preset matching usage context
    /// - Returns: Optimized URL with transforms applied, or nil if invalid
    static func optimized(_ fullUrl: String, variant: ImageVariant) -> URL? {
        guard let transform = transforms[variant],
              let url = URL(string: fullUrl) else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "tr", value: transform)]
        return components?.url
    }
}