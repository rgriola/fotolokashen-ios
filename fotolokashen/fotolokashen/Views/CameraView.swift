import SwiftUI
import CoreLocation

/// Camera view for capturing photos with GPS
struct CameraView: View {
    
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) var dismiss
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Callback when photo is captured
    var onPhotoCaptured: ((UIImage, CLLocation?) -> Void)?
    
    var body: some View {
        ZStack {
            // Camera preview (full screen)
            if cameraService.isAuthorized {
                CameraPreview(session: cameraService.getCaptureSession())
                    .ignoresSafeArea()
            } else {
                // Permission denied view
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
            
            // Top bar
            VStack {
                HStack {
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // GPS indicator
                    HStack(spacing: 6) {
                        Image(systemName: locationManager.location != nil ? "location.fill" : "location.slash.fill")
                            .font(.caption)
                        
                        Text(locationManager.location != nil ? "GPS" : "No GPS")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(locationManager.location != nil ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                    .cornerRadius(20)
                }
                .padding()
                
                Spacer()
            }
            
            // Bottom controls
            VStack {
                Spacer()
                
                // GPS coordinates display
                if let location = locationManager.location {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text("Accuracy: ±\(Int(location.horizontalAccuracy))m")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.bottom, 8)
                }
                
                // Capture button
                Button(action: {
                    capturePhoto()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 82, height: 82)
                    }
                }
                .padding(.bottom, 40)
            }
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
        .onChange(of: cameraService.capturedImage) { oldValue, newValue in
            if let image = newValue {
                handleCapturedPhoto(image)
            }
        }
        .onChange(of: cameraService.errorMessage) { oldValue, newValue in
            if let error = newValue {
                errorMessage = error
                showingError = true
            }
        }
    }
    
    // MARK: - Methods
    
    private func setupCamera() async {
        // Request camera permission
        await cameraService.requestPermission()
        
        guard cameraService.isAuthorized else {
            return
        }
        
        // Setup camera session
        do {
            try await cameraService.setupSession()
            cameraService.startSession()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        // Request location permission and start tracking
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
        // Call the callback with the captured image and current location
        onPhotoCaptured?(image, locationManager.location)
        
        // Dismiss the camera view
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
