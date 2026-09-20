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
        case "LIVE ANCHOR", "LIVE_ANCHOR":
            return UIColor(hex: "#573014")  //- Dark Brown
        case "REPORTER LIVE", "REPORTER_LIVE":
            return UIColor(hex: "#7F461D") // Medium Brown
        case "BROLL":
            return UIColor(hex: "#A85D27")  //- Brown
        case "STORY":
           // return UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1.0) // 
            return UIColor(hex: "#D17330")  //- Red
        case "INTERVIEW":
           // return UIColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0) // 
           return UIColor(hex: "#F58638")  //- Orange
        case "EVENT":
            return UIColor(hex: "#F5DC38")  //- Lime
        case "STAKEOUT":
            return UIColor(hex: "#4C5C54")  //- Gray
        case "DRONE":
            return UIColor(hex: "#5A8F75")  //- Cyan
        case "SCENE":
            return UIColor(hex: "#53C28C")  //- Green
        case "BATHROOM":
            return UIColor(hex: "#38F59A")  //- Sky Blue
        case "OTHER":
            return UIColor(hex: "#CD38F5")  //- Slate
            
        // Admin-Only Location Types
        case "HQ":
            return UIColor(hex: "#AA53C2")  //- Dark Blue
        case "BUREAU":
            return UIColor(hex: "#835A8F")  //- Violet
        case "REMOTE STAFF", "REMOTE_STAFF":
            return UIColor(hex: "#584C5C")  //- Pink
        case "STORAGE":
            return UIColor(hex: "#C2B353")  //- Stone
        // Default fallback
        default:
            return UIColor(hex: "#44F538")  //- Slate (OTHER)
        }
    }

    static let PUBLIC_LOCATION_COLOR = Color(hex: "#173057") 
    
    static let HOME_MARKER_COLOR = Color(hex: "#2D5DA8") //- Slate (OTHER)

    static let USER_LOCATION_COLOR  = Color(hex: "#4285F4") //- Pink
    
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
