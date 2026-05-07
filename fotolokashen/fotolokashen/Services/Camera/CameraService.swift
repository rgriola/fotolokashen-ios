import Foundation
@preconcurrency import AVFoundation
import UIKit
import Combine
import Photos

/// Camera service for capturing photos
class CameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthorized = false
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    @Published var isSessionReady = false
    @Published var currentZoom: CGFloat = 1.0
    @Published var currentExposureBias: Float = 0.0
    
    // MARK: - Properties
    
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?

    /// Multiplier mapping user-facing display zoom → device `videoZoomFactor`.
    /// On a virtual device that includes the ultra-wide lens (e.g. `.builtInTripleCamera`,
    /// `.builtInDualWideCamera`), the ultra-wide sits at `videoZoomFactor = 1.0` and the
    /// wide "1x" lens sits at the first switch-over factor (typically 2.0). We expose a
    /// display zoom where 0.5 == ultra-wide and 1.0 == wide.
    /// On a single wide-only device this stays 1.0, so 1.0x display == 1.0x device.
    private var displayZoomMultiplier: CGFloat = 1.0

    /// Min/max zoom range (in user-facing display units)
    var minZoom: CGFloat { 1.0 / displayZoomMultiplier }
    var maxZoom: CGFloat {
        guard let device = videoDeviceInput?.device else { return 5.0 }
        return min(device.activeFormat.videoMaxZoomFactor / displayZoomMultiplier, 10.0)
    }
    
    /// Exposure bias range from device
    var minExposureBias: Float {
        videoDeviceInput?.device.minExposureTargetBias ?? -8.0
    }
    var maxExposureBias: Float {
        videoDeviceInput?.device.maxExposureTargetBias ?? 8.0
    }
    
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
        
        // Configure session on background queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                captureSession.beginConfiguration()
                captureSession.sessionPreset = .photo

                // Prefer a virtual multi-camera that includes the ultra-wide lens so the
                // 0.5x preset is selectable. Fall back to wide-only on devices without it.
                let camera = Self.preferredBackCamera()
                guard let camera else {
                    captureSession.commitConfiguration()
                    continuation.resume(throwing: CameraError.noCameraAvailable)
                    return
                }

                // Determine the display-zoom multiplier from the device's switch-over
                // factors. For dual/triple cameras the first switch-over (typically 2.0)
                // is the wide lens, which we treat as the user's "1x".
                let firstSwitchOver = camera.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 1.0
                self.displayZoomMultiplier = CGFloat(firstSwitchOver > 0 ? firstSwitchOver : 1.0)

                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    self.videoDeviceInput = input
                    
                    if captureSession.canAddInput(input) {
                        captureSession.addInput(input)
                    } else {
                        captureSession.commitConfiguration()
                        continuation.resume(throwing: CameraError.cannotAddInput)
                        return
                    }
                    
                    if captureSession.canAddOutput(photoOutput) {
                        captureSession.addOutput(photoOutput)
                    } else {
                        captureSession.commitConfiguration()
                        continuation.resume(throwing: CameraError.cannotAddOutput)
                        return
                    }
                    
                    captureSession.commitConfiguration()
                    dlog("CameraService", "Session configured successfully (device: \(camera.localizedName), multiplier: \(self.displayZoomMultiplier))")

                    // Start at the wide lens (display 1.0x) so framing matches the prior default.
                    do {
                        try camera.lockForConfiguration()
                        camera.videoZoomFactor = self.displayZoomMultiplier
                        camera.unlockForConfiguration()
                        DispatchQueue.main.async { self.currentZoom = 1.0 }
                    } catch {
                        dlog("CameraService", "Initial zoom set failed: \(error)")
                    }

                    continuation.resume()
                    
                } catch {
                    captureSession.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Start camera session
    func startSession() {
        guard !isSimulator else { return }
        
        sessionQueue.async { [self] in
            if !captureSession.isRunning {
                captureSession.startRunning()
                dlog("CameraService", "Session started, isRunning: \(captureSession.isRunning)")
                
                // Confirm session is running on main thread
                DispatchQueue.main.async {
                    self.isSessionReady = self.captureSession.isRunning
                    dlog("CameraService", "isSessionReady set to: \(self.isSessionReady)")
                }
            }
        }
    }
    
    /// Stop camera session
    func stopSession() {
        guard !isSimulator else { return }
        
        sessionQueue.async { [self] in
            if captureSession.isRunning {
                captureSession.stopRunning()
                dlog("CameraService", "Session stopped")
                
                DispatchQueue.main.async {
                    self.isSessionReady = false
                }
            }
        }
    }
    
    /// Get capture session for preview
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    // MARK: - Zoom
    
    /// Set zoom factor in user-facing display units (e.g. 0.5, 1.0, 2.0).
    /// Internally translated to the device's `videoZoomFactor` via `displayZoomMultiplier`.
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        let clampedDisplay = min(max(factor, minZoom), maxZoom)
        let deviceFactor = clampedDisplay * displayZoomMultiplier
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let bounded = min(max(deviceFactor, 1.0), device.activeFormat.videoMaxZoomFactor)
                device.videoZoomFactor = bounded
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.currentZoom = clampedDisplay
                }
            } catch {
                #if DEBUG
                dlog("CameraService", "Zoom error: \(error)")
                #endif
            }
        }
    }

    // MARK: - Device Selection

    /// Choose the best back camera. Prefer virtual devices that include the ultra-wide
    /// lens so the 0.5x preset is available; fall back to wide-only otherwise.
    private static func preferredBackCamera() -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,      // ultra-wide + wide + tele
            .builtInDualWideCamera,    // ultra-wide + wide
            .builtInDualCamera,        // wide + tele (no ultra-wide)
            .builtInWideAngleCamera    // wide only
        ]
        for type in preferredTypes {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                return device
            }
        }
        return nil
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
        guard let device = videoDeviceInput?.device else { return }
        // Convert SwiftUI point (origin top-left) to AVCapture device point
        let focusPoint = CGPoint(x: point.y / viewSize.height,
                                 y: 1.0 - point.x / viewSize.width)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
                #if DEBUG
                dlog("CameraService", "Focus at \(focusPoint)")
                #endif
            } catch {
                #if DEBUG
                dlog("CameraService", "Focus error: \(error)")
                #endif
            }
        }
    }
    
    /// Set exposure compensation bias (in EV)
    func setExposureBias(_ bias: Float) {
        guard let device = videoDeviceInput?.device else { return }
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped) { _ in
                    DispatchQueue.main.async {
                        self.currentExposureBias = clamped
                    }
                }
                device.unlockForConfiguration()
            } catch {
                #if DEBUG
                dlog("CameraService", "Exposure bias error: \(error)")
                #endif
            }
        }
    }
    
    /// Reset exposure to neutral
    func resetExposure() {
        setExposureBias(0)
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
            
            DispatchQueue.main.async {
                self.capturedImage = testImage
            }
            return
        }
        
        // Real device capture
        sessionQueue.async { [self] in
            guard captureSession.isRunning else {
                DispatchQueue.main.async {
                    self.errorMessage = "Camera session not running"
                }
                return
            }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            
            photoOutput.capturePhoto(with: settings, delegate: self)
            dlog("CameraService", "Capturing photo...")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                dlog("CameraService", "Capture error: \(error.localizedDescription)")
                return
            }
            
            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                self.errorMessage = "Failed to process photo"
                return
            }
            
            self.capturedImage = image
            dlog("CameraService", "Photo captured successfully")
            dlog("CameraService", "Image size: \(image.size)")
            
            // Save to photo library
            self.saveToPhotoLibrary(image: image)
        }
    }
    
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
                } else if let error = error {
                    dlog("CameraService", "Error saving to library: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Camera Errors

enum CameraError: Error, LocalizedError {
    case notAuthorized
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access not authorized"
        case .noCameraAvailable:
            return "No camera available on this device"
        case .cannotAddInput:
            return "Cannot add camera input"
        case .cannotAddOutput:
            return "Cannot add photo output"
        }
    }
}
