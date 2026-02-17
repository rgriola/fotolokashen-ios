import SwiftUI
import CoreLocation

/// Camera view for capturing photos with GPS — supports rotation and pinch-to-zoom
struct CameraView: View {

    @StateObject private var cameraService = CameraService()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var pinchBaseZoom: CGFloat = 1.0

    // Callback when photo is captured
    var onPhotoCaptured: ((UIImage, CLLocation?) -> Void)?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Camera preview (full screen)
                if cameraService.isAuthorized && cameraService.isSessionReady {
                    CameraPreview(session: cameraService.getCaptureSession())
                        .ignoresSafeArea()
                        .gesture(
                            MagnificationGesture()
                                .onChanged { scale in
                                    cameraService.handlePinchZoom(
                                        scale: scale,
                                        initialZoom: pinchBaseZoom
                                    )
                                }
                                .onEnded { _ in
                                    pinchBaseZoom = cameraService.currentZoom
                                }
                        )
                } else if cameraService.isAuthorized && !cameraService.isSessionReady {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Starting Camera...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    // Permission denied
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Please enable camera access in Settings to take photos")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }

                // --- HUD overlays (safe-area aware) ---

                // Close button — top-left
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.leading, geo.safeAreaInsets.leading + 16)
                    Spacer()
                }

                // Zoom controls — right side, vertically centred
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Button {
                            cameraService.zoomIn()
                            pinchBaseZoom = cameraService.currentZoom
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        // Zoom level indicator
                        Text(String(format: "%.1f×", cameraService.currentZoom))
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(6)

                        Button {
                            cameraService.zoomOut()
                            pinchBaseZoom = cameraService.currentZoom
                        } label: {
                            Image(systemName: "minus")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, geo.safeAreaInsets.trailing + 16)

                // Compact GPS badge — bottom-left corner
                VStack {
                    Spacer()
                    HStack {
                        gpsBadge
                            .padding(.leading, geo.safeAreaInsets.leading + 16)
                            .padding(.bottom, geo.safeAreaInsets.bottom + 100)
                        Spacer()
                    }
                }

                // Capture button — bottom centre
                VStack {
                    Spacer()
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 82, height: 82)
                        }
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await setupCamera()
        }
        .onDisappear {
            cameraService.stopSession()
            locationManager.stopTracking()
        }
        .onChange(of: cameraService.capturedImage) { _, newValue in
            if let image = newValue {
                handleCapturedPhoto(image)
            }
        }
        .onChange(of: cameraService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showingError = true
            }
        }
    }

    // MARK: - GPS Badge

    /// Compact GPS badge for the lower-left corner
    @ViewBuilder
    private var gpsBadge: some View {
        if let location = locationManager.location {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                    .font(.system(size: 10, design: .monospaced))
                Text("±\(Int(location.horizontalAccuracy))m")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.55))
            .cornerRadius(8)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 10))
                Text("No GPS")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.6))
            .cornerRadius(8)
        }
    }

    // MARK: - Methods

    private func setupCamera() async {
        await cameraService.requestPermission()

        guard cameraService.isAuthorized else { return }

        do {
            try await cameraService.setupSession()
            cameraService.startSession()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse ||
                    locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startTracking()
        }
    }

    private func capturePhoto() {
        cameraService.capturePhoto()
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        onPhotoCaptured?(image, locationManager.location)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
