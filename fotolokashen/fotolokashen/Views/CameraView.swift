import SwiftUI
import CoreLocation

/// Camera view with native-style zoom dial, tap-to-focus, exposure control, GPS badge,
/// and multi-photo session support with disk-backed storage.
///
/// Phase 2a-2: session capture pipeline lives in `CameraSessionViewModel`. HUD
/// components (focus square, exposure slider, zoom dial, GPS badge, permission
/// view, thumbnail strip) live in `Views/Camera/CameraHUDComponents.swift`.
struct CameraView: View {

    /// Maximum photos per session (forwards to VM for backward compat).
    static let maxSessionPhotos = CameraSessionViewModel.maxSessionPhotos

    @StateObject private var cameraService = CameraService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var session = CameraSessionViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var pinchBaseZoom: CGFloat = 1.0

    // Focus indicator
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusSquare = false

    // Exposure
    @State private var showExposureSlider = false
    @State private var exposureDragOffset: CGFloat = 0

    // Zoom dial
    @State private var showZoomDial = false

    // GPS
    @State private var showCoordinates = false

    // Photo Library picker
    @State private var showLibraryPicker = false

    // Library-from-Camera transition overlay (B2)
    @State private var isTransitioningToForm = false

    // Callbacks
    var onSessionComplete: (([SessionCapture]) -> Void)?
    var onLibraryPhotosPicked: (([PipelinePhoto]) -> Void)?

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
                        .onTapGesture { location in
                            handleTapToFocus(at: location, in: geo.size)
                        }
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
                    CameraPermissionDeniedView()
                }

                // --- Focus square ---
                if showFocusSquare, let point = focusPoint {
                    FocusSquareView()
                        .position(point)
                }

                // --- Exposure slider (right side, appears after tap-to-focus) ---
                if showExposureSlider, let point = focusPoint {
                    ExposureSlider(
                        bias: Binding(
                            get: { cameraService.currentExposureBias },
                            set: { cameraService.setExposureBias($0) }
                        ),
                        minBias: cameraService.minExposureBias,
                        maxBias: cameraService.maxExposureBias
                    )
                    .position(x: min(max(point.x + 60, 40), geo.size.width - 40),
                              y: point.y)
                    .transition(.opacity)
                }

                // --- HUD overlays ---

                // Top bar: Close | Flash | (spacer) | GPS badge
                VStack {
                    HStack(spacing: 12) {
                        // Close button
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

                        // Flash mode button — Apple-style top bar (B4)
                        if !cameraService.isUsingFrontCamera {
                            Button {
                                cameraService.cycleFlashMode()
                            } label: {
                                Image(systemName: cameraService.flashIconName)
                                    .font(.title3)
                                    .foregroundColor(cameraService.flashIconName.contains("slash") ? .white : .yellow)
                                    .padding(12)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }

                        Spacer()

                        // GPS badge
                        CameraGPSBadge(
                            location: locationManager.location,
                            showCoordinates: $showCoordinates
                        )
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.horizontal, 16)
                    Spacer()
                }

                // Done button — top-right below GPS badge (visible when photos captured)
                if !session.sessionCaptures.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                finishSession()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Done")
                                        .font(.headline)
                                    Text("(\(session.sessionCaptures.count))")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.brand)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, geo.safeAreaInsets.top + 48)
                        .padding(.trailing, geo.safeAreaInsets.trailing + 16)
                        Spacer()
                    }
                }

                // Capture flash overlay
                if session.captureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // Library-from-Camera transition overlay (B2)
                if isTransitioningToForm {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.white)
                            Text("Preparing photos…")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .transition(.opacity)
                    .allowsHitTesting(true)
                }

                // Bottom controls stack
                VStack(spacing: 0) {
                    Spacer()

                    // Thumbnail strip — shows captured photos
                    if !session.sessionCaptures.isEmpty {
                        CameraThumbnailStrip(
                            captures: session.sessionCaptures,
                            onRemove: { session.removeCapture($0) }
                        )
                    }

                    // Zoom dial or zoom pill
                    if showZoomDial {
                        ZoomDialView(
                            currentZoom: $cameraService.currentZoom,
                            minZoom: cameraService.minZoom,
                            maxZoom: min(cameraService.maxZoom, 10.0),
                            onZoomChanged: { newZoom in
                                cameraService.setZoom(newZoom)
                                pinchBaseZoom = newZoom
                            },
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showZoomDial = false
                                }
                            }
                        )
                        .padding(.bottom, 12)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        // Zoom pill button (tap to expand dial)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showZoomDial = true
                            }
                        } label: {
                            Text(zoomLabel)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(cameraService.currentZoom > 1.01 ? .yellow : .white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.bottom, 12)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Bottom controls: Library | Capture (with count badge) | Camera flip (B3)
                    HStack(spacing: 32) {
                        // Library button
                        Button {
                            showLibraryPicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        // Capture button with count badge
                        ZStack(alignment: .topTrailing) {
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
                            .disabled(session.isCaptureDisabled)
                            .opacity(session.isWritingToDisk ? 0.6 : 1.0)

                            // Photo count badge
                            if !session.sessionCaptures.isEmpty {
                                Text("\(session.sessionCaptures.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 22, minHeight: 22)
                                    .background(Color.brand)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -4)
                            }
                        }

                        // Front/back camera toggle — next to shutter (B3)
                        Button {
                            cameraService.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
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
        .sheet(isPresented: $showLibraryPicker) {
            PhotoPickerView(selectionLimit: 20) { [self] photos in
                guard !photos.isEmpty else { return }
                // B2: Show transition overlay before dismissing camera
                isTransitioningToForm = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onLibraryPhotosPicked?(photos)
                }
            }
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
                // B1: Pass raw photo data so it writes to disk with full EXIF intact
                session.handleCapturedPhoto(
                    image,
                    rawData: cameraService.capturedPhotoData,
                    location: locationManager.location
                )
                // Clear so cameraService is ready for the next shot.
                cameraService.capturedImage = nil
                cameraService.capturedPhotoData = nil
            }
        }
        .onChange(of: cameraService.errorMessage) { _, newValue in
            if let error = newValue {
                errorMessage = error
                showingError = true
            }
        }
    }

    // MARK: - Zoom Label

    private var zoomLabel: String {
        let z = cameraService.currentZoom
        if z < 10 {
            return String(format: "%.1f", z)
        }
        return String(format: "%.0f", z)
    }

    // MARK: - Tap to Focus

    private func handleTapToFocus(at point: CGPoint, in size: CGSize) {
        // Dismiss zoom dial if open
        if showZoomDial {
            withAnimation(.easeOut(duration: 0.2)) {
                showZoomDial = false
            }
        }

        // Set focus point on camera
        cameraService.focusAt(point: point, in: size)

        // Show focus square
        focusPoint = point
        showFocusSquare = true
        showExposureSlider = true

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showFocusSquare = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showExposureSlider = false
            }
        }
    }

    // MARK: - Camera Setup & Capture

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

    /// Finish the session — hand captures to callback and dismiss.
    private func finishSession() {
        guard !session.sessionCaptures.isEmpty else {
            dismiss()
            return
        }
        onSessionComplete?(session.sessionCaptures)
        dismiss()
    }

    /// Clean up temp files for any captures not handed off.
    /// Forwards to `CameraSessionViewModel` so existing call-sites (ContentView) keep working.
    static func cleanupTempFiles() {
        CameraSessionViewModel.cleanupTempFiles()
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
