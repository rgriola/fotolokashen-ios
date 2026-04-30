import SwiftUI
import UIKit

/// Centralized location type colors and icons matching web app location-constants.ts
/// This is the single source of truth for all type-related styling in the app
struct LocationTypeColors {
    
    // MARK: - Type Color Mapping
    
    /// Get the UIColor for a location type (for use with Google Maps markers)
    static func uiColor(for type: String) -> UIColor {
        let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        switch normalizedType {
        // Standard Location Types
        case "BROLL":
            return UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1.0) // #3B82F6 - Blue
        case "STORY":
            return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1.0) // #EF4444 - Red
        case "INTERVIEW":
            return UIColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0) // #8B5CF6 - Purple
        case "LIVE ANCHOR", "LIVE_ANCHOR":
            return UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1.0) // #DC2626 - Dark Red
        case "REPORTER LIVE", "REPORTER_LIVE":
            return UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1.0) // #F59E0B - Orange
        case "STAKEOUT":
            return UIColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1.0) // #6B7280 - Gray
        case "DRONE":
            return UIColor(red: 0.024, green: 0.714, blue: 0.831, alpha: 1.0) // #06B6D4 - Cyan
        case "SCENE":
            return UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1.0) // #22C55E - Green
        case "EVENT":
            return UIColor(red: 0.518, green: 0.800, blue: 0.086, alpha: 1.0) // #84CC16 - Lime
        case "BATHROOM":
            return UIColor(red: 0.055, green: 0.647, blue: 0.914, alpha: 1.0) // #0EA5E9 - Sky Blue
        case "OTHER":
            return UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1.0) // #64748B - Slate
            
        // Admin-Only Location Types
        case "HQ":
            return UIColor(red: 0.118, green: 0.251, blue: 0.686, alpha: 1.0) // #1E40AF - Dark Blue
        case "BUREAU":
            return UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1.0) // #7C3AED - Violet
        case "REMOTE STAFF", "REMOTE_STAFF":
            return UIColor(red: 0.925, green: 0.282, blue: 0.600, alpha: 1.0) // #EC4899 - Pink
        case "STORAGE":
            return UIColor(red: 0.471, green: 0.443, blue: 0.424, alpha: 1.0) // #78716C - Stone
            
        // Default fallback
        default:
            return UIColor(red: 0.392, green: 0.455, blue: 0.545, alpha: 1.0) // #64748B - Slate (OTHER)
        }
    }
    
    /// Get the SwiftUI Color for a location type (for use in SwiftUI views)
    static func color(for type: String) -> Color {
        return Color(uiColor(for: type))
    }
    
    // MARK: - Type Icon Mapping
    
    /// Get the SF Symbol icon name for a location type
    static func icon(for type: String) -> String {
        let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        switch normalizedType {
        case "BROLL": return "film"
        case "STORY": return "doc.text"
        case "INTERVIEW": return "person.wave.2"
        case "LIVE ANCHOR", "LIVE_ANCHOR": return "antenna.radiowaves.left.and.right"
        case "REPORTER LIVE", "REPORTER_LIVE": return "mic.fill"
        case "STAKEOUT": return "eye"
        case "DRONE": return "airplane"
        case "SCENE": return "mappin.and.ellipse"
        case "EVENT": return "calendar"
        case "BATHROOM": return "toilet"
        case "OTHER": return "ellipsis.circle"
        case "HQ": return "building.2.fill"
        case "BUREAU": return "building"
        case "REMOTE STAFF", "REMOTE_STAFF": return "person.crop.circle.badge.checkmark"
        case "STORAGE": return "archivebox"
        default: return "mappin.circle.fill"
        }
    }
    
    // MARK: - All Types
    
    /// All standard location types (non-admin)
    static let standardTypes: [String] = [
        "BROLL",
        "STORY",
        "INTERVIEW",
        "LIVE ANCHOR",
        "REPORTER LIVE",
        "STAKEOUT",
        "DRONE",
        "SCENE",
        "EVENT",
        "BATHROOM",
        "OTHER"
    ]
    
    /// Admin-only location types
    static let adminTypes: [String] = [
        "HQ",
        "BUREAU",
        "REMOTE STAFF",
        "STORAGE"
    ]
    
    /// All location types
    static var allTypes: [String] {
        return standardTypes + adminTypes
    }
    
    /// Get available types based on admin status
    static func availableTypes(isAdmin: Bool) -> [String] {
        return isAdmin ? allTypes : standardTypes
    }
}

// MARK: - SwiftUI View Extension for Type Badge

extension View {
    /// Apply a type badge style with the appropriate color
    func typeBadgeStyle(for type: String) -> some View {
        self
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(LocationTypeColors.color(for: type).opacity(0.2))
            .foregroundColor(LocationTypeColors.color(for: type))
            .clipShape(Capsule())
    }
}
