import Foundation
import AVFoundation

/// A value-only snapshot used to update camera controls on the main actor.
nonisolated struct CameraDeviceState: Sendable {
    let isFrontCamera: Bool
    let currentZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let exposureBias: Float
    let minExposureBias: Float
    let maxExposureBias: Float
    let revision: UInt64
}

nonisolated enum CameraFlashMode: Sendable {
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

// MARK: - Camera Errors

nonisolated enum CameraError: Error, LocalizedError, Sendable {
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
