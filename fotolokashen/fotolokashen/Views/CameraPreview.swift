import SwiftUI
import AVFoundation

/// Camera preview layer wrapper for SwiftUI
struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.updateOrientation()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
    }
}

/// Custom UIView that properly handles AVCaptureVideoPreviewLayer layout and rotation
class PreviewView: UIView {

    var session: AVCaptureSession? {
        didSet {
            if let session = session, let layer = previewLayer {
                layer.session = session
            }
            updateOrientation()
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer? {
        return layer as? AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
        registerForOrientationNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
        registerForOrientationNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupLayer() {
        backgroundColor = .black
        previewLayer?.videoGravity = .resizeAspectFill
    }

    private func registerForOrientationNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func orientationDidChange() {
        updateOrientation()
    }

    /// Update the preview layer's connection orientation to match the device
    func updateOrientation() {
        guard let connection = previewLayer?.connection else { return }

        let deviceOrientation = UIDevice.current.orientation
        let angle: CGFloat

        switch deviceOrientation {
        case .portrait:
            angle = 90
        case .portraitUpsideDown:
            angle = 270
        case .landscapeLeft:
            angle = 0
        case .landscapeRight:
            angle = 180
        default:
            return
        }

        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Preview layer automatically matches view bounds since it IS the layer
    }
}
