import Foundation
import SwiftUI
import GoogleMaps

/// Generates custom camera icon markers matching the web app design
class MarkerIconGenerator {
    
    /// Color mapping for location types (matching web app location-constants.ts)
    static func color(for type: String) -> UIColor {
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
    
    /// Generate a camera icon marker matching the web app design
    /// - Parameters:
    ///   - type: Location type (e.g., "BROLL", "STORY")
    ///   - size: Size of the marker (default: 40x48)
    /// - Returns: UIImage of the custom camera marker
    static func cameraMarker(for type: String, size: CGSize = CGSize(width: 40, height: 48)) -> UIImage {
        let color = self.color(for: type)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Define dimensions
            let squareSize: CGFloat = 40
            let pointerHeight: CGFloat = 8
            let cornerRadius: CGFloat = 4
            let borderWidth: CGFloat = 2
            
            // Draw the square with rounded corners
            let squareRect = CGRect(x: 0, y: 0, width: squareSize, height: squareSize)
            let squarePath = UIBezierPath(roundedRect: squareRect, cornerRadius: cornerRadius)
            
            // Fill the square with the type color
            ctx.setFillColor(color.cgColor)
            squarePath.fill()
            
            // Draw white border
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(borderWidth)
            squarePath.stroke()
            
            // Draw camera icon (white)
            drawCameraIcon(in: ctx, rect: squareRect, color: .white)
            
            // Draw pointer/pin at bottom
            let pointerPath = UIBezierPath()
            pointerPath.move(to: CGPoint(x: squareSize / 2, y: squareSize + pointerHeight))
            pointerPath.addLine(to: CGPoint(x: squareSize / 2 - 8, y: squareSize))
            pointerPath.addLine(to: CGPoint(x: squareSize / 2 + 8, y: squareSize))
            pointerPath.close()
            
            ctx.setFillColor(color.cgColor)
            pointerPath.fill()
        }
    }
    
    /// Draw camera icon SVG path
    private static func drawCameraIcon(in context: CGContext, rect: CGRect, color: UIColor) {
        // Camera icon is centered in a 20x20 area within the 40x40 square
        let iconSize: CGFloat = 20
        let iconInset = (rect.width - iconSize) / 2
        
        context.saveGState()
        
        // Translate to center the icon
        context.translateBy(x: iconInset, y: iconInset)
        
        // Scale to fit 20x20 into the drawing area
        let scale = iconSize / 24.0
        context.scaleBy(x: scale, y: scale)
        
        // Set drawing attributes
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Draw camera body path
        // Path: M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z
        let cameraBody = UIBezierPath()
        cameraBody.move(to: CGPoint(x: 23, y: 19))
        cameraBody.addCurve(to: CGPoint(x: 21, y: 21), controlPoint1: CGPoint(x: 23, y: 20.1), controlPoint2: CGPoint(x: 22.1, y: 21))
        cameraBody.addLine(to: CGPoint(x: 3, y: 21))
        cameraBody.addCurve(to: CGPoint(x: 1, y: 19), controlPoint1: CGPoint(x: 1.9, y: 21), controlPoint2: CGPoint(x: 1, y: 20.1))
        cameraBody.addLine(to: CGPoint(x: 1, y: 8))
        cameraBody.addCurve(to: CGPoint(x: 3, y: 6), controlPoint1: CGPoint(x: 1, y: 6.9), controlPoint2: CGPoint(x: 1.9, y: 6))
        cameraBody.addLine(to: CGPoint(x: 7, y: 6))
        cameraBody.addLine(to: CGPoint(x: 9, y: 3))
        cameraBody.addLine(to: CGPoint(x: 15, y: 3))
        cameraBody.addLine(to: CGPoint(x: 17, y: 6))
        cameraBody.addLine(to: CGPoint(x: 21, y: 6))
        cameraBody.addCurve(to: CGPoint(x: 23, y: 8), controlPoint1: CGPoint(x: 22.1, y: 6), controlPoint2: CGPoint(x: 23, y: 6.9))
        cameraBody.addLine(to: CGPoint(x: 23, y: 19))
        
        cameraBody.stroke()
        
        // Draw camera lens (circle)
        let lensCenter = CGPoint(x: 12, y: 13)
        let lensRadius: CGFloat = 4
        
        context.strokeEllipse(in: CGRect(
            x: lensCenter.x - lensRadius,
            y: lensCenter.y - lensRadius,
            width: lensRadius * 2,
            height: lensRadius * 2
        ))
        
        context.restoreGState()
    }
    
    /// Create a GMSMarker with custom camera icon
    static func createMarker(for location: Location, at position: CLLocationCoordinate2D) -> GMSMarker {
        let marker = GMSMarker(position: position)
        marker.icon = cameraMarker(for: location.type ?? "")
        marker.title = location.name
        marker.snippet = location.address
        marker.userData = location
        
        // Anchor at the bottom point of the pin
        marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
        
        return marker
    }
}
