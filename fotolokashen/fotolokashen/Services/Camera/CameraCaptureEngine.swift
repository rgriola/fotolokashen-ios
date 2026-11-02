import Foundation
@preconcurrency import AVFoundation

/// Owns every mutable capture-session object. All access to its AVFoundation
/// state is serialized on `sessionQueue`; callbacks carry only Sendable values
/// back to the main-actor `CameraService`, which holds only published UI state.
///
/// `@unchecked Sendable` is limited to this boundary: mutable state is only
/// read or written on `sessionQueue` (including asynchronous device callbacks,
/// which re-enter that queue), and the preview session is read via `sync`.
nonisolated final class CameraCaptureEngine: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
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
