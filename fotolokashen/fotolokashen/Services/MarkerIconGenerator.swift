import Foundation
import SwiftUI
import GoogleMaps

/// Generates custom camera icon markers matching the web app design
class MarkerIconGenerator {
    
    /// Color mapping for location types - delegates to centralized LocationTypeColors
    static func color(for type: String) -> UIColor {
        return LocationTypeColors.uiColor(for: type)
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

    /// Generate a purple social marker for friends'/public locations
    /// Uses a distinct purple color to differentiate from user's own locations
    static func socialMarker(size: CGSize = CGSize(width: 32, height: 40)) -> UIImage {
        let purpleColor = UIColor(red: 0.36, green: 0.30, blue: 1.0, alpha: 1.0) // brand purple

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext

            let squareSize = size.width
            let pointerHeight: CGFloat = 8
            let cornerRadius: CGFloat = 4
            let borderWidth: CGFloat = 1.5

            // Draw the square with rounded corners
            let squareRect = CGRect(x: 0, y: 0, width: squareSize, height: squareSize)
            let squarePath = UIBezierPath(roundedRect: squareRect, cornerRadius: cornerRadius)

            ctx.setFillColor(purpleColor.cgColor)
            squarePath.fill()

            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(borderWidth)
            squarePath.stroke()

            // Draw a person icon (simpler than camera for social markers)
            drawPersonIcon(in: ctx, rect: squareRect, color: .white)

            // Draw pointer/pin at bottom
            let pointerPath = UIBezierPath()
            pointerPath.move(to: CGPoint(x: squareSize / 2, y: squareSize + pointerHeight))
            pointerPath.addLine(to: CGPoint(x: squareSize / 2 - 6, y: squareSize))
            pointerPath.addLine(to: CGPoint(x: squareSize / 2 + 6, y: squareSize))
            pointerPath.close()

            ctx.setFillColor(purpleColor.cgColor)
            pointerPath.fill()
        }
    }

    /// Draw a simple person icon for social markers
    private static func drawPersonIcon(in context: CGContext, rect: CGRect, color: UIColor) {
        let iconSize: CGFloat = 16
        let iconInset = (rect.width - iconSize) / 2

        context.saveGState()
        context.translateBy(x: iconInset, y: iconInset)

        let scale = iconSize / 24.0
        context.scaleBy(x: scale, y: scale)

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Head circle
        context.strokeEllipse(in: CGRect(x: 8, y: 2, width: 8, height: 8))

        // Body path
        let bodyPath = UIBezierPath()
        bodyPath.move(to: CGPoint(x: 20, y: 21))
        bodyPath.addLine(to: CGPoint(x: 20, y: 19))
        bodyPath.addCurve(to: CGPoint(x: 16, y: 15), controlPoint1: CGPoint(x: 20, y: 16.8), controlPoint2: CGPoint(x: 18.2, y: 15))
        bodyPath.addLine(to: CGPoint(x: 8, y: 15))
        bodyPath.addCurve(to: CGPoint(x: 4, y: 19), controlPoint1: CGPoint(x: 5.8, y: 15), controlPoint2: CGPoint(x: 4, y: 16.8))
        bodyPath.addLine(to: CGPoint(x: 4, y: 21))
        bodyPath.stroke()

        context.restoreGState()
    }
}
