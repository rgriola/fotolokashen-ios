import SwiftUI
import CoreLocation

// MARK: - Legacy Brand Color Aliases (use Color.brand / Color.brandDark from AppColors.swift)
extension Color {
    static let brandPurple = Color.brand
    static let brandPurpleDark = Color.brandDark
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToMapTab = Notification.Name("navigateToMapTab")
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        if authService.isAuthenticated {
            LoggedInView()
        } else {
            NavigationStack {
                LoginView()
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager

    // Native UI states for auth flow feedback
    @State private var showAwaitingVerification = false
    @State private var showAwaitingPasswordReset = false
    @State private var showAccountExistsAlert = false
    @State private var showPasswordResetComplete = false

    var body: some View {
        ZStack {
            // Brand purple background
            Color.brandPurple
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                Image("FLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                
                Text("fotolokashen")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Production Location Intelligence")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                VStack(spacing: 15) {
                    Button(action: {
                        authService.startLogin()
                    }) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPurple))
                            } else {
                                Image(systemName: "person.circle.fill")
                                Text("Sign In")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.brandPurple)
                        .cornerRadius(12)
                    }
                    .disabled(authService.isLoading)
                    
                    Button(action: {
                        authService.startRegistration()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Create Account")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .disabled(authService.isLoading)

                    Button(action: {
                        authService.startForgotPassword()
                    }) {
                        Text("Forgot Password?")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .disabled(authService.isLoading)
                    
                    Text("Secure sign-in via fotolokashen.com")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Backend: \(ConfigLoader.shared.backendBaseURL)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom)
            }
            .padding()
        }
        .navigationBarHidden(true)
        // Auto-login after email verification deep link
        .onChange(of: deepLinkManager.emailVerified) { _, verified in
            guard verified else { return }
            deepLinkManager.emailVerified = false

            if let token = deepLinkManager.autoLoginToken {
                // Auto-login: exchange the one-time token for OAuth tokens directly
                deepLinkManager.autoLoginToken = nil
                Task {
                    await authService.autoLoginWithToken(token)
                }
            } else {
                // Fallback: no token available, prompt manual login
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authService.startLogin()
                }
            }
        }
        // Registration success — panel closed, show native "Check Your Email"
        .onChange(of: authService.awaitingVerification) { _, awaiting in
            if awaiting {
                authService.awaitingVerification = false
                showAwaitingVerification = true
            }
        }
        // Forgot password submitted — panel closed, show native "Check Your Email"
        .onChange(of: authService.awaitingPasswordReset) { _, awaiting in
            if awaiting {
                authService.awaitingPasswordReset = false
                showAwaitingPasswordReset = true
            }
        }
        // Password reset completed via deep link from Safari
        .onChange(of: deepLinkManager.passwordResetComplete) { _, complete in
            if complete {
                deepLinkManager.passwordResetComplete = false
                showPasswordResetComplete = true
            }
        }
        // Account already exists — auth-redirect with reason
        .onChange(of: authService.errorMessage) { _, message in
            if message == "You already have an account. Please log in." {
                authService.errorMessage = nil
                showAccountExistsAlert = true
            }
        }
        // MARK: - Native Sheets & Alerts
        .sheet(isPresented: $showAwaitingVerification) {
            CheckEmailSheet(
                title: "Check Your Email",
                message: "We sent a verification link to your email address. Tap the link to verify your account, then you'll be logged in automatically.",
                icon: "envelope.badge",
                buttonTitle: "Got It",
                onDismiss: { showAwaitingVerification = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAwaitingPasswordReset) {
            CheckEmailSheet(
                title: "Check Your Email",
                message: "If an account exists with that email, you'll receive a password reset link. The link expires in 15 minutes.",
                icon: "envelope.open",
                buttonTitle: "Got It",
                onDismiss: { showAwaitingPasswordReset = false }
            )
            .presentationDetents([.medium])
        }
        .alert("Account Already Exists", isPresented: $showAccountExistsAlert) {
            Button("Log In") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    authService.startLogin()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You already have an account with this email. Would you like to log in instead?")
        }
        .alert("Password Updated", isPresented: $showPasswordResetComplete) {
            Button("Log In") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    authService.startLogin()
                }
            }
        } message: {
            Text("Your password has been updated successfully. Please log in with your new password.")
        }
    }
}

// MARK: - Check Email Sheet

/// Reusable native sheet for "check your email" states (post-registration, post-forgot-password)
private struct CheckEmailSheet: View {
    let title: String
    let message: String
    let icon: String
    let buttonTitle: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.brandPurple)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundColor(.brandPurple)
                    Text("Check your spam or junk folder")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(.brandPurple)
                    Text("Wait a few minutes if it hasn't arrived")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onDismiss) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPurple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Logged In View

struct LoggedInView: View {
    @ObservedObject private var locationStore = LocationStore.shared
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showingCamera = false
    @State private var capturedPhoto: PhotoCapture?
    @State private var libraryPhotos: [PipelinePhoto]?
    @State private var deepLinkLocation: Location?
    @State private var showDeepLinkDetail = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Locations list
            LocationListView()
                .tabItem {
                    Label("Locations", systemImage: "list.bullet")
                }
                .tag(1)

            // Map
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)

            // Center camera tab - placeholder that triggers camera
            Color.clear
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(2)

            // People search & social
            PeopleSearchView()
                .tabItem {
                    Label("People", systemImage: "person.2")
                }
                .tag(3)

            // Profile
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(4)
        }
        .tint(.brandPurple)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                // Capture tab tapped — open camera and bounce back
                showingCamera = true
                selectedTab = previousTab
            } else {
                previousTab = newTab
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image, location in
                capturedPhoto = PhotoCapture(image: image, location: location)
            } onLibraryPhotosPicked: { photos in
                guard !photos.isEmpty else { return }
                showingCamera = false
                libraryPhotos = photos
            }
        }
        .sheet(item: $capturedPhoto) { capture in
            CreateLocationView(
                photo: capture.image,
                photoLocation: capture.location
            ) { location in
                locationStore.addLocation(location)
            }
        }
        .sheet(isPresented: Binding(
            get: { libraryPhotos != nil },
            set: { if !$0 { libraryPhotos = nil } }
        )) {
            if let photos = libraryPhotos {
                LibraryCreateLocationView(
                    initialPhotos: photos,
                    locationStore: locationStore
                )
            }
        }
        // Map tab navigation (from address tap in LocationDetailView)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToMapTab)) { _ in
            selectedTab = 1
        }
        // Deep link navigation
        .onChange(of: deepLinkManager.pendingLocationId) { _, locationId in
            guard let locationId else { return }
            Task {
                if let location = await deepLinkManager.resolveLocation(id: locationId) {
                    deepLinkLocation = location
                    showDeepLinkDetail = true
                }
                deepLinkManager.clearPendingNavigation()
            }
        }
        .sheet(isPresented: $showDeepLinkDetail) {
            if let location = deepLinkLocation {
                NavigationStack {
                    LocationDetailView(location: location)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    showDeepLinkDetail = false
                                }
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Photo Capture

/// Wrapper that presents CreateLocationView pre-loaded with library photos.
/// Uses the first photo's EXIF GPS (if available) or the device's current location.
private struct LibraryCreateLocationView: View {
    let initialPhotos: [PipelinePhoto]
    let locationStore: LocationStore
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        let gps = initialPhotos.first?.gpsCoordinate
        let clLocation: CLLocation? = if let gps {
            CLLocation(latitude: gps.lat, longitude: gps.lng)
        } else {
            locationManager.location
        }

        CreateLocationView(
            photoLocation: clLocation
        ) { location in
            locationStore.addLocation(location)
        }
        .onAppear {
            locationManager.startTracking()
        }
    }
}

struct PhotoCapture: Identifiable {
    let id = UUID()
    let image: UIImage
    let location: CLLocation?
}

#Preview {
    ContentView()
}
