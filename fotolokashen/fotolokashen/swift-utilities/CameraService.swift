import Foundation
@preconcurrency import AVFoundation
import UIKit
import Combine

/// Camera service for capturing photos
class CameraService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthorized = false
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    @Published var isSessionReady = false
    
    // MARK: - Properties
    
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
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
        
        print("[CameraService] Authorization status: \(isAuthorized)")
    }
    
    /// Setup camera session
    func setupSession() async throws {
        // On simulator, just mark as ready
        if isSimulator {
            print("[CameraService] Running on simulator - camera capture limited")
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
                
                // Add camera input
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    captureSession.commitConfiguration()
                    continuation.resume(throwing: CameraError.noCameraAvailable)
                    return
                }
                
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    
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
                    
                    DispatchQueue.main.async {
                        self.isSessionReady = true
                        print("[CameraService] Session configured successfully")
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
                print("[CameraService] Session started")
            }
        }
    }
    
    /// Stop camera session
    func stopSession() {
        guard !isSimulator else { return }
        
        sessionQueue.async { [self] in
            if captureSession.isRunning {
                captureSession.stopRunning()
                print("[CameraService] Session stopped")
            }
        }
    }
    
    /// Get capture session for preview
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    // MARK: - Photo Capture
    
    /// Capture photo
    func capturePhoto() {
        // On simulator, create a test image
        if isSimulator {
            print("[CameraService] Simulator: Creating test image")
            
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
            print("[CameraService] Capturing photo...")
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
                print("[CameraService] Capture error: \(error.localizedDescription)")
                return
            }
            
            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                self.errorMessage = "Failed to process photo"
                return
            }
            
            self.capturedImage = image
            print("[CameraService] Photo captured successfully")
            print("[CameraService] Image size: \(image.size)")
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
