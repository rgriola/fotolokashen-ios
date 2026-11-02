import Foundation
@preconcurrency import AVFoundation
import UIKit
import Combine
import Photos

/// Camera service for capturing photos
@MainActor
final class CameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthorized = false
    @Published var capturedImage: UIImage?
    /// Raw photo data from AVCapturePhoto — preserves full EXIF (ISO, shutter, aperture, lens).
    /// Published alongside capturedImage so CameraSessionViewModel can write it to disk directly.
    @Published var capturedPhotoData: Data?
    @Published var errorMessage: String?
    /// Current flash mode: .auto → .on → .off (B4)
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    /// Whether the device is using the front camera (B3)
    @Published var isUsingFrontCamera = false
    @Published var isSessionReady = false
    @Published var currentZoom: CGFloat = 1.0
    @Published var currentExposureBias: Float = 0.0
    
    // MARK: - Properties
    
    private let sessionController = CameraCaptureEngine()
    private var minDisplayZoom: CGFloat = 1
    private var maxDisplayZoom: CGFloat = 5
    private var minBias: Float = -8
    private var maxBias: Float = 8
    private var lastAppliedRevision: UInt64 = 0

    /// Min/max zoom range (in user-facing display units)
    var minZoom: CGFloat { minDisplayZoom }
    var maxZoom: CGFloat { maxDisplayZoom }
    
    /// Exposure bias range from device
    var minExposureBias: Float { minBias }
    var maxExposureBias: Float { maxBias }
    
    // Check if running on simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Session Management
    
    /// Request camera permission
    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            await MainActor.run { isAuthorized = true }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { isAuthorized = granted }
        default:
            await MainActor.run { isAuthorized = false }
        }
        
        dlog("CameraService", "Authorization status: \(isAuthorized)")
    }
    
    /// Setup camera session
    func setupSession() async throws {
        // On simulator, just mark as ready
        if isSimulator {
            dlog("CameraService", "Running on simulator - camera capture limited")
            await MainActor.run { isSessionReady = true }
            return
        }
        
        guard isAuthorized else {
            throw CameraError.notAuthorized
        }
        
        let state = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<CameraDeviceState, Error>) in
            sessionController.configure { result in
                continuation.resume(with: result)
            }
        }
        apply(state)
    }
    
    /// Start camera session
    func startSession() {
        guard !isSimulator else { return }
        
        sessionController.start { [weak self] isRunning, revision in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard revision >= self.lastAppliedRevision else { return }
                self.lastAppliedRevision = revision
                self.isSessionReady = isRunning
                dlog("CameraService", "Session started, isRunning: \(isRunning)")
            }
        }
    }
    
    /// Stop camera session
    func stopSession() {
        guard !isSimulator else { return }
        
        sessionController.stop { [weak self] revision in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard revision >= self.lastAppliedRevision else { return }
                self.lastAppliedRevision = revision
                self.isSessionReady = false
                dlog("CameraService", "Session stopped")
            }
        }
    }
    
    /// Get capture session for preview
    func getCaptureSession() -> AVCaptureSession {
        sessionController.previewSession()
    }
    
    // MARK: - Zoom
    
    /// Set zoom factor in user-facing display units (e.g. 0.5, 1.0, 2.0).
    /// Internally translated to the device's `videoZoomFactor` via `displayZoomMultiplier`.
    func setZoom(_ factor: CGFloat) {
        sessionController.setZoom(factor) { [weak self] result in
            guard let (zoom, revision) = result else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard revision >= self.lastAppliedRevision else { return }
                self.currentZoom = zoom
                self.lastAppliedRevision = revision
            }
        }
    }
    
    /// Zoom in by a step
    func zoomIn() {
        setZoom(currentZoom * 1.5)
    }
    
    /// Zoom out by a step
    func zoomOut() {
        setZoom(currentZoom / 1.5)
    }
    
    /// Handle pinch gesture scale
    func handlePinchZoom(scale: CGFloat, initialZoom: CGFloat) {
        setZoom(initialZoom * scale)
    }
    
    // MARK: - Focus & Exposure
    
    /// Focus and meter at a normalised point (0…1, 0…1) in the preview
    func focusAt(point: CGPoint, in viewSize: CGSize) {
        // Convert SwiftUI point (origin top-left) to AVCapture device point
        let focusPoint = CGPoint(x: point.y / viewSize.height,
                                 y: 1.0 - point.x / viewSize.width)
        sessionController.focus(at: focusPoint) {
            #if DEBUG
            dlog("CameraService", "Focus at \(focusPoint)")
            #endif
        }
    }

    /// Set exposure compensation bias (in EV)
    func setExposureBias(_ bias: Float) {
        sessionController.setExposureBias(bias) { [weak self] result in
            guard let (bias, revision) = result else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard revision >= self.lastAppliedRevision else { return }
                self.currentExposureBias = bias
                self.lastAppliedRevision = revision
            }
        }
    }
    
    /// Reset exposure to neutral
    func resetExposure() {
        setExposureBias(0)
    }

    // MARK: - Camera Switch (B3)

    /// Toggle between front and back cameras.
    func switchCamera() {
        guard !isSimulator else { return }
        sessionController.switchCamera { [weak self] state in
            guard let state else {
                dlog("CameraService", "Switch camera failed")
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.apply(state)
            }
        }
    }

    private func apply(_ state: CameraDeviceState) {
        guard state.revision >= lastAppliedRevision else { return }
        lastAppliedRevision = state.revision
        isUsingFrontCamera = state.isFrontCamera
        currentZoom = state.currentZoom
        currentExposureBias = state.exposureBias
        minDisplayZoom = state.minZoom
        maxDisplayZoom = state.maxZoom
        minBias = state.minExposureBias
        maxBias = state.maxExposureBias
    }

    // MARK: - Flash Mode (B4)

    /// Cycle flash mode: auto → on → off → auto (matches Apple Camera app).
    func cycleFlashMode() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on:   flashMode = .off
        case .off:  flashMode = .auto
        @unknown default: flashMode = .auto
        }
    }

    /// SF Symbol name for the current flash mode.
    var flashIconName: String {
        switch flashMode {
        case .auto: return AppIcons.boltBadgeAutomatic
        case .on:   return AppIcons.boltFill
        case .off:  return AppIcons.boltSlashFill
        @unknown default: return AppIcons.boltBadgeAutomatic
        }
    }

    
    // MARK: - Photo Capture
    
    /// Capture photo
    func capturePhoto() {
        // On simulator, create a test image
        if isSimulator {
            dlog("CameraService", "Simulator: Creating test image")
            
            // Create a gradient test image
            let size = CGSize(width: 1200, height: 1600)
            let renderer = UIGraphicsImageRenderer(size: size)
            let testImage = renderer.image { context in
                // Gradient background
                let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                
                // Add camera icon
                let iconText = "📸"
                let iconAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 120)
                ]
                let iconSize = iconText.size(withAttributes: iconAttrs)
                let iconRect = CGRect(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2 - 60,
                    width: iconSize.width,
                    height: iconSize.height
                )
                iconText.draw(in: iconRect, withAttributes: iconAttrs)
                
                // Add text
                let text = "Simulator Test Photo"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 36),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: iconRect.maxY + 30,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
                
                // Add timestamp
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
                let timestampAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                ]
                let timestampSize = timestamp.size(withAttributes: timestampAttrs)
                let timestampRect = CGRect(
                    x: (size.width - timestampSize.width) / 2,
                    y: textRect.maxY + 16,
                    width: timestampSize.width,
                    height: timestampSize.height
                )
                timestamp.draw(in: timestampRect, withAttributes: timestampAttrs)
            }
            
            capturedImage = testImage
            return
        }
        
        // Snapshot UI state before crossing to the session queue. The controller
        // uses the current output/device when this queued operation executes.
        let requestedFlashMode = CameraFlashMode(flashMode)
        sessionController.capturePhoto(flashMode: requestedFlashMode) { [weak self] imageData, errorMessage in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let errorMessage {
                    self.errorMessage = errorMessage
                    dlog("CameraService", "Capture failed")
                    return
                }
                guard let imageData, let image = UIImage(data: imageData) else {
                    self.errorMessage = "Failed to process photo"
                    return
                }
                self.capturedPhotoData = imageData
                self.capturedImage = image
                dlog("CameraService", "Photo captured successfully")
                dlog("CameraService", "Image size: \(image.size)")
                self.saveToPhotoLibrary(image: image)
            }
        }
    }
}

// MARK: - Photo Library

@MainActor
extension CameraService {
    /// Save image to photo library
    private func saveToPhotoLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                dlog("CameraService", "Photo library access not authorized")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    dlog("CameraService", "Photo saved to library")
                } else if error != nil {
                    dlog("CameraService", "Saving to library failed")
                }
            }
        }
    }
}
