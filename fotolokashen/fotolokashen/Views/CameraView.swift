import SwiftUI
import CoreLocation

/// Camera view with native-style zoom dial, tap-to-focus, exposure control, GPS badge,
/// and multi-photo session support with disk-backed storage.
struct CameraView: View {

    /// Maximum photos per session (disk-backed, memory stays flat)
    static let maxSessionPhotos = 50

    @StateObject private var cameraService = CameraService()
    @StateObject private var locationManager = LocationManager()
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

    // Multi-photo session (disk-backed)
    @State private var sessionCaptures: [SessionCapture] = []
    @State private var isWritingToDisk = false
    @State private var captureFlash = false  // white flash animation

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
                    permissionDeniedView
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

                // GPS badge — top-right
                VStack {
                    HStack {
                        Spacer()
                        gpsBadge
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.trailing, geo.safeAreaInsets.trailing + 16)
                    Spacer()
                }

                // Done button — top-right below GPS badge (visible when photos captured)
                if !sessionCaptures.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                finishSession()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Done")
                                        .font(.headline)
                                    Text("(\(sessionCaptures.count))")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.brandPurple)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, geo.safeAreaInsets.top + 48)
                        .padding(.trailing, geo.safeAreaInsets.trailing + 16)
                        Spacer()
                    }
                }

                // Capture flash overlay
                if captureFlash {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                // Bottom controls stack
                VStack(spacing: 0) {
                    Spacer()

                    // Thumbnail strip — shows captured photos
                    if !sessionCaptures.isEmpty {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sessionCaptures) { capture in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: capture.thumbnail)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 56, height: 56)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                                )
                                            // Delete button
                                            Button {
                                                removeCapture(capture)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                        .id(capture.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(height: 64)
                            .padding(.bottom, 8)
                            .onChange(of: sessionCaptures.count) { _, _ in
                                if let last = sessionCaptures.last {
                                    withAnimation {
                                        proxy.scrollTo(last.id, anchor: .trailing)
                                    }
                                }
                            }
                        }
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

                    // Bottom controls: Library | Capture (with count badge) | (spacer)
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
                            .disabled(isWritingToDisk || sessionCaptures.count >= Self.maxSessionPhotos)
                            .opacity(isWritingToDisk ? 0.6 : 1.0)

                            // Photo count badge
                            if !sessionCaptures.isEmpty {
                                Text("\(sessionCaptures.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 22, minHeight: 22)
                                    .background(Color.brandPurple)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -4)
                            }
                        }

                        // Spacer to balance the layout
                        Color.clear
                            .frame(width: 50, height: 50)
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
            PhotoPickerView(selectionLimit: 20) { photos in
                onLibraryPhotosPicked?(photos)
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

    // MARK: - Zoom Label

    private var zoomLabel: String {
        let z = cameraService.currentZoom
        if z < 10 {
            return String(format: "%.1f", z)
        }
        return String(format: "%.0f", z)
    }

    // MARK: - GPS Badge

    @ViewBuilder
    private var gpsBadge: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCoordinates.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: locationManager.location != nil ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 10))
                if showCoordinates, let loc = locationManager.location {
                    Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                        .font(.system(size: 10, design: .monospaced))
                    Text("±\(Int(loc.horizontalAccuracy))m")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, showCoordinates ? 8 : 6)
            .padding(.vertical, 5)
            .background(locationManager.location != nil ? Color.green.opacity(0.75) : Color.red.opacity(0.6))
            .cornerRadius(8)
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
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

    /// Handle a captured photo — write to disk, generate thumbnail, add to session.
    private func handleCapturedPhoto(_ image: UIImage) {
        isWritingToDisk = true

        // Flash animation
        withAnimation(.easeIn(duration: 0.05)) { captureFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.15)) { captureFlash = false }
        }

        let location = locationManager.location

        // Write to disk on a background queue to keep UI responsive
        Task.detached(priority: .userInitiated) {
            // Compress to JPEG
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                await MainActor.run { isWritingToDisk = false }
                return
            }

            // Write to temp directory
            let filename = "capture_\(UUID().uuidString).jpg"
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("fotolokashen_session", isDirectory: true)

            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let fileURL = tempDir.appendingPathComponent(filename)

            do {
                try jpegData.write(to: fileURL)
            } catch {
                #if DEBUG
                print("[Camera] Failed to write capture to disk: \(error)")
                #endif
                await MainActor.run { isWritingToDisk = false }
                return
            }

            // Generate small thumbnail (150×150)
            let thumbnailSize = CGSize(width: 150, height: 150)
            let thumbnail: UIImage
            let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
            thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
            }

            let capture = SessionCapture(
                fileURL: fileURL,
                thumbnail: thumbnail,
                location: location,
                capturedAt: Date()
            )

            await MainActor.run {
                sessionCaptures.append(capture)
                isWritingToDisk = false
                // Clear the capturedImage so cameraService is ready for next
                cameraService.capturedImage = nil
                #if DEBUG
                print("[Camera] Session capture \(sessionCaptures.count) saved to \(fileURL.lastPathComponent)")
                #endif
            }
        }
    }

    /// Remove a capture and delete its temp file.
    private func removeCapture(_ capture: SessionCapture) {
        sessionCaptures.removeAll { $0.id == capture.id }
        try? FileManager.default.removeItem(at: capture.fileURL)
    }

    /// Finish the session — hand captures to callback and dismiss.
    private func finishSession() {
        guard !sessionCaptures.isEmpty else {
            dismiss()
            return
        }
        onSessionComplete?(sessionCaptures)
        dismiss()
    }

    /// Clean up temp files for any captures not handed off.
    static func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fotolokashen_session", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Focus Square View

/// Yellow focus square that animates in, like native iOS Camera
struct FocusSquareView: View {
    @State private var scale: CGFloat = 1.4
    @State private var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 70, height: 70)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = 1.0
                }
                // Pulse
                withAnimation(.easeInOut(duration: 0.5).delay(0.3).repeatCount(2, autoreverses: true)) {
                    opacity = 0.5
                }
                withAnimation(.easeInOut(duration: 0.2).delay(1.3)) {
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Exposure Slider

/// Vertical sun brightness slider that appears next to the focus point
struct ExposureSlider: View {
    @Binding var bias: Float
    let minBias: Float
    let maxBias: Float

    @State private var dragOffset: CGFloat = 0
    private let sliderHeight: CGFloat = 140

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow.opacity(0.8))

            ZStack(alignment: .center) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2, height: sliderHeight)

                // Thumb
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 16, height: 16)
                    .offset(y: thumbOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let half = sliderHeight / 2
                                let clamped = min(max(value.location.y - half, -half), half)
                                // Map: top = max EV, bottom = min EV
                                let normalised = Float(-clamped / half) // -1 to 1
                                let ev = normalised * min(maxBias, 4.0) // clamp practical range
                                bias = ev
                            }
                    )
            }
            .frame(height: sliderHeight)

            Image(systemName: "sun.min.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow.opacity(0.5))
        }
    }

    private var thumbOffset: CGFloat {
        let practicalMax = min(maxBias, 4.0)
        guard practicalMax > 0 else { return 0 }
        let normalised = CGFloat(bias / practicalMax)
        return -normalised * (sliderHeight / 2)
    }
}

// MARK: - Zoom Dial View

/// Horizontal zoom dial that expands from the zoom pill — mimics native iOS Camera
struct ZoomDialView: View {
    @Binding var currentZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    var onZoomChanged: (CGFloat) -> Void
    var onDismiss: () -> Void

    // Preset stops
    private var presets: [CGFloat] {
        var stops: [CGFloat] = [0.5, 1.0, 2.0]
        if maxZoom >= 3.0 { stops.append(3.0) }
        if maxZoom >= 5.0 { stops.append(5.0) }
        return stops
    }

    var body: some View {
        HStack(spacing: 0) {
            // Preset buttons
            ForEach(presets, id: \.self) { preset in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        onZoomChanged(max(preset, minZoom))
                    }
                } label: {
                    Text(presetLabel(preset))
                        .font(.system(size: 13, weight: isActive(preset) ? .bold : .medium, design: .monospaced))
                        .foregroundColor(isActive(preset) ? .yellow : .white)
                        .frame(width: 44, height: 36)
                }
            }

            // Close dial
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 36)
            }
        }
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.65))
        .clipShape(Capsule())
    }

    private func presetLabel(_ value: CGFloat) -> String {
        if value < 1.0 {
            return String(format: ".%0.f", value * 10)
        }
        return String(format: "%.0f", value)
    }

    private func isActive(_ preset: CGFloat) -> Bool {
        abs(currentZoom - preset) < 0.15
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
