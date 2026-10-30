import Foundation
@preconcurrency import AVFoundation
import UIKit
import Combine
import Photos

/// A value-only snapshot used to update camera controls on the main actor.
nonisolated private struct CameraDeviceState: Sendable {
    let isFrontCamera: Bool
    let currentZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let exposureBias: Float
    let minExposureBias: Float
    let maxExposureBias: Float
    let revision: UInt64
}

nonisolated private enum CameraFlashMode: Sendable {
    case auto
    case on
    case off

    init(_ mode: AVCaptureDevice.FlashMode) {
        switch mode {
        case .auto: self = .auto
        case .on: self = .on
        case .off: self = .off
        @unknown default: self = .auto
        }
    }

    var avCaptureMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
}

/// Owns every mutable capture-session object. All access to its AVFoundation
/// state is serialized on `sessionQueue`; callbacks carry only Sendable values
/// back to the main-actor CameraService.
///
/// `@unchecked Sendable` is limited to this boundary: mutable state is only
/// read or written on `sessionQueue` (including asynchronous device callbacks,
/// which re-enter that queue), and the preview session is read via `sync`.
nonisolated private final class CameraSessionController: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let captureSession = AVCaptureSession()
    private let capturePhotoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var displayZoomMultiplier: CGFloat = 1
    private var currentPosition: AVCaptureDevice.Position?
    private var generation: UInt64 = 0
    private var exposureRequest: UInt64 = 0
    private var pendingPhotoCompletions: [Int64: @Sendable (Data?, String?) -> Void] = [:]
    private var revision: UInt64 = 0

    /// The preview layer needs the session reference. Read it synchronously
    /// through the owning queue; session configuration/mutation remains here.
    func previewSession() -> AVCaptureSession {
        dispatchPrecondition(condition: .notOnQueue(sessionQueue))
        return sessionQueue.sync {
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            return captureSession
        }
    }

    func configure(
        completion: @escaping @Sendable (Result<CameraDeviceState, Error>) -> Void
    ) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            captureSession.beginConfiguration()
            captureSession.sessionPreset = .photo

            guard let camera = Self.preferredBackCamera() else {
                captureSession.commitConfiguration()
                completion(.failure(CameraError.noCameraAvailable))
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                guard captureSession.canAddInput(input) else {
                    captureSession.commitConfiguration()
                    completion(.failure(CameraError.cannotAddInput))
                    return
                }
                captureSession.addInput(input)

                guard captureSession.canAddOutput(capturePhotoOutput) else {
                    captureSession.removeInput(input)
                    captureSession.commitConfiguration()
                    completion(.failure(CameraError.cannotAddOutput))
                    return
                }
                captureSession.addOutput(capturePhotoOutput)
                captureSession.commitConfiguration()

                videoDeviceInput = input
                currentPosition = camera.position
                displayZoomMultiplier = Self.zoomMultiplier(for: camera)
                generation &+= 1
                revision &+= 1

                do {
                    try camera.lockForConfiguration()
                    camera.videoZoomFactor = displayZoomMultiplier
                    camera.setExposureTargetBias(0, completionHandler: nil)
                    camera.unlockForConfiguration()
                } catch {
                    // Configuration is still usable; report its actual device
                    // bounds and retain the prior 1x UI default.
                    completion(.success(makeState(for: camera, zoom: 1, exposure: 0)))
                    return
                }

                completion(.success(makeState(for: camera, zoom: 1, exposure: 0)))
                dlog("CameraService", "Session configured successfully")
            } catch {
                captureSession.commitConfiguration()
                completion(.failure(error))
            }
        }
    }

    func start(completion: @escaping @Sendable (Bool, UInt64) -> Void) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
            revision &+= 1
            completion(captureSession.isRunning, revision)
        }
    }

    func stop(completion: @escaping @Sendable (UInt64) -> Void) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            revision &+= 1
            completion(revision)
        }
    }

    func setZoom(
        _ requestedZoom: CGFloat,
        completion: @escaping @Sendable ((CGFloat, UInt64)?) -> Void
    ) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            guard let device = videoDeviceInput?.device else {
                completion(nil)
                return
            }

            let minZoom = 1 / displayZoomMultiplier
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor / displayZoomMultiplier, 10)
            let displayZoom = min(max(requestedZoom, minZoom), maxZoom)
            let deviceZoom = min(
                max(displayZoom * displayZoomMultiplier, 1),
                device.activeFormat.videoMaxZoomFactor
            )
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = deviceZoom
                device.unlockForConfiguration()
                revision &+= 1
                completion((displayZoom, revision))
            } catch {
                dlog("CameraService", "Zoom adjustment failed")
                completion(nil)
            }
        }
    }

    func focus(at point: CGPoint, completion: @escaping @Sendable () -> Void) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            guard let device = videoDeviceInput?.device else {
                completion()
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                dlog("CameraService", "Focus adjustment failed")
            }
            completion()
        }
    }

    func setExposureBias(
        _ requestedBias: Float,
        completion: @escaping @Sendable ((Float, UInt64)?) -> Void
    ) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            guard let device = videoDeviceInput?.device else {
                completion(nil)
                return
            }
            let boundedBias = min(
                max(requestedBias, device.minExposureTargetBias),
                device.maxExposureTargetBias
            )
            let requestGeneration = generation
            exposureRequest &+= 1
            let requestID = exposureRequest
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(boundedBias) { [weak self] _ in
                    guard let self else { return }
                    self.sessionQueue.async {
                        dispatchPrecondition(condition: .onQueue(self.sessionQueue))
                        // Ignore a late completion from a device that has since
                        // been replaced by switchCamera().
                        guard self.generation == requestGeneration else {
                            completion(nil)
                            return
                        }
                        guard self.exposureRequest == requestID else {
                            completion(nil)
                            return
                        }
                        self.revision &+= 1
                        completion((boundedBias, self.revision))
                    }
                }
                device.unlockForConfiguration()
            } catch {
                dlog("CameraService", "Exposure bias adjustment failed")
                completion(nil)
            }
        }
    }

    func switchCamera(
        completion: @escaping @Sendable (CameraDeviceState?) -> Void
    ) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            guard let activePosition: AVCaptureDevice.Position = self.currentPosition else {
                completion(nil)
                return
            }
            let newPosition: AVCaptureDevice.Position = activePosition == .front ? .back : .front
            let device = newPosition == .back
                ? Self.preferredBackCamera()
                : AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            guard let device,
                  let newInput = try? AVCaptureDeviceInput(device: device) else {
                completion(nil)
                return
            }

            let oldInput = videoDeviceInput
            captureSession.beginConfiguration()
            if let oldInput {
                captureSession.removeInput(oldInput)
            }
            guard captureSession.canAddInput(newInput) else {
                if let oldInput, captureSession.canAddInput(oldInput) {
                    captureSession.addInput(oldInput)
                }
                captureSession.commitConfiguration()
                completion(nil)
                return
            }
            captureSession.addInput(newInput)

            let multiplier = Self.zoomMultiplier(for: device)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = multiplier
                device.setExposureTargetBias(0, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                captureSession.removeInput(newInput)
                if let oldInput, captureSession.canAddInput(oldInput) {
                    captureSession.addInput(oldInput)
                }
                captureSession.commitConfiguration()
                completion(nil)
                return
            }

            captureSession.commitConfiguration()
            videoDeviceInput = newInput
            currentPosition = device.position
            displayZoomMultiplier = multiplier
            generation &+= 1
            revision &+= 1
            completion(makeState(for: device, zoom: 1, exposure: 0))
        }
    }

    func capturePhoto(
        flashMode: CameraFlashMode,
        completion: @escaping @Sendable (Data?, String?) -> Void
    ) {
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            guard captureSession.isRunning else {
                completion(nil, "Camera session not running")
                return
            }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = videoDeviceInput?.device.hasFlash == true
                ? flashMode.avCaptureMode
                : .off
            pendingPhotoCompletions[settings.uniqueID] = completion
            capturePhotoOutput.capturePhoto(with: settings, delegate: self)
            dlog("CameraService", "Capturing photo...")
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let id = photo.resolvedSettings.uniqueID
        let imageData = photo.fileDataRepresentation()
        let errorMessage = error?.localizedDescription
        sessionQueue.async { [self] in
            dispatchPrecondition(condition: .onQueue(sessionQueue))
            let completion = pendingPhotoCompletions.removeValue(forKey: id)
            completion?(imageData, errorMessage)
        }
    }

    private func makeState(
        for device: AVCaptureDevice,
        zoom: CGFloat,
        exposure: Float
    ) -> CameraDeviceState {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        return CameraDeviceState(
            isFrontCamera: device.position == .front,
            currentZoom: zoom,
            minZoom: 1 / displayZoomMultiplier,
            maxZoom: min(device.activeFormat.videoMaxZoomFactor / displayZoomMultiplier, 10),
            exposureBias: exposure,
            minExposureBias: device.minExposureTargetBias,
            maxExposureBias: device.maxExposureTargetBias,
            revision: revision
        )
    }

    private static func zoomMultiplier(for device: AVCaptureDevice) -> CGFloat {
        let firstSwitchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 1
        return CGFloat(firstSwitchOver > 0 ? firstSwitchOver : 1)
    }

    private static func preferredBackCamera() -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        for type in preferredTypes {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                return device
            }
        }
        return nil
    }
}

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
    
    private let sessionController = CameraSessionController()
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
        case .auto: return "bolt.badge.automatic"
        case .on:   return "bolt.fill"
        case .off:  return "bolt.slash.fill"
        @unknown default: return "bolt.badge.automatic"
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

// MARK: - Camera Errors

enum CameraError: Error, LocalizedError, Sendable {
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
