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
        // Session updates handled by PreviewView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
    }
}

/// Custom UIView that properly handles AVCaptureVideoPreviewLayer layout
class PreviewView: UIView {
    
    var session: AVCaptureSession? {
        didSet {
            if let session = session, let layer = previewLayer {
                layer.session = session
            }
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
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        backgroundColor = .black
        previewLayer?.videoGravity = .resizeAspectFill
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Preview layer automatically matches view bounds since it IS the layer
    }
}
