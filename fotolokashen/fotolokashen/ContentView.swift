import SwiftUI
import CoreLocation

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToMapTab = Notification.Name("navigateToMapTab")
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                LoggedInView()
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
        .errorPresenter()
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Native UI states for auth flow feedback
    @State private var showAwaitingVerification = false
    @State private var showAwaitingPasswordReset = false
    @State private var showAccountExistsAlert = false
    @State private var showPasswordResetComplete = false
    @State private var pendingLoginTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Purple to black gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.brand, Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    loginContent
                }
            } else {
                loginContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            #if DEBUG
            LaunchTimer.mark("LoginView.onAppear — LOGIN SCREEN VISIBLE")
            #endif
        }
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
                authService.startLogin()
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
                icon: AppIcons.envelopeBadge,
                buttonTitle: "Got It",
                onDismiss: { showAwaitingVerification = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAwaitingPasswordReset) {
            CheckEmailSheet(
                title: "Check Your Email",
                message: "If an account exists with that email, you'll receive a password reset link. The link expires in 15 minutes.",
                icon: AppIcons.envelopeOpen,
                buttonTitle: "Got It",
                onDismiss: { showAwaitingPasswordReset = false }
            )
            .presentationDetents([.medium])
        }
        .alert("Account Already Exists", isPresented: $showAccountExistsAlert) {
            Button("Log In") {
                startLoginAfterAlertDismisses()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You already have an account with this email. Would you like to log in instead?")
        }
        .alert("Password Updated", isPresented: $showPasswordResetComplete) {
            Button("Log In") {
                startLoginAfterAlertDismisses()
            }
        } message: {
            Text("Your password has been updated successfully. Please log in with your new password.")
        }
        .onDisappear {
            pendingLoginTask?.cancel()
        }
    }

    private var loginContent: some View {
        VStack(spacing: 30) {
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if dynamicTypeSize.isAccessibilitySize {
                Image("Flogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: 160)
                    .accessibilityLabel("Fotolokashen")
            } else {
                Image("Flogo")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Fotolokashen")
            }

            Text("Production Knowledge")
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            VStack(spacing: 15) {
                Button(action: {
                    authService.startLogin()
                }) {
                    Group {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.brand)
                        } else {
                            authButtonContent(icon: AppIcons.personCircleFill, title: "Sign In")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .frame(minWidth: 44, minHeight: 44)
                    .background(Color.white)
                    .foregroundStyle(Color.brand)
                    .cornerRadius(12)
                    .contentShape(Rectangle())
                }
                .disabled(authService.isLoading)
                .accessibilityLabel("Sign In")
                .accessibilityValue(authService.isLoading ? Text("Loading") : Text(""))
                .accessibilityIdentifier("login.signInButton")

                Button(action: {
                    authService.startRegistration()
                }) {
                    authButtonContent(icon: AppIcons.followAdd, title: "Create Account")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Color.white.opacity(0.2))
                        .foregroundStyle(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .disabled(authService.isLoading)
                .accessibilityLabel("Create Account")

                Button(action: {
                    authService.startForgotPassword()
                }) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(authService.isLoading)

                #if DEBUG
                // Shows which backend the app is hitting, to confirm dev-server connectivity.
                Text("Connected to: \(ConfigLoader.shared.backendBaseURL)")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 40)

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
        }
        .padding()
    }

    @ViewBuilder
    private func authButtonContent(icon: String, title: LocalizedStringKey) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func startLoginAfterAlertDismisses() {
        pendingLoginTask?.cancel()
        pendingLoginTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            authService.startLogin()
            pendingLoginTask = nil
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
                .foregroundStyle(Color.brand)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: AppIcons.tray)
                        .foregroundStyle(Color.brand)
                    Text("Check your spam or junk folder")
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                }
                HStack(spacing: 8) {
                    Image(systemName: AppIcons.clock)
                        .foregroundStyle(Color.brand)
                    Text("Wait a few minutes if it hasn't arrived")
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                }
            }

            Button(action: onDismiss) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brand)
                    .foregroundStyle(Color.white)
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
    @State private var sessionCaptures: [SessionCapture]?
    @State private var libraryPhotos: [PipelinePhoto]?
    @State private var deepLinkLocation: Location?
    @State private var showDeepLinkDetail = false

    // Holds library photos until the camera fullScreenCover is fully dismissed,
    // preventing the SwiftUI race condition where both transitions fire simultaneously.
    @State private var pendingLibraryPhotos: [PipelinePhoto]?

    /// Spots is portrait-only on iPhone until its header has a landscape layout;
    /// the camera keeps its own rotation handling.
    private func updateOrientationLock() {
        AppOrientation.setPortraitLocked(selectedTab == 1 && !showingCamera)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Locations list
            LocationListView()
                .tabItem {
                    Label("Spots", systemImage: AppIcons.locationsList)
                }
                .tag(1)

            // Map
            MapView()
                .tabItem {
                    Label("Map", systemImage: AppIcons.map)
                }
                .tag(0)

            // Center camera tab - placeholder that triggers camera
            Color.clear
                .tabItem {
                    Label("Create", systemImage: AppIcons.cameraFill)
                }
                .tag(2)

            // People search & social
            PeopleSearchView()
                .tabItem {
                    Label("People", systemImage: AppIcons.people)
                }
                .tag(3)

            // Profile
            ProfileView()
                .tabItem {
                    Label("Settings", systemImage: AppIcons.personCircle)
                }
                .tag(4)
        }
        .tint(.brand)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 2 {
                // Capture tab tapped — open camera and bounce back
                showingCamera = true
                selectedTab = previousTab
            } else {
                previousTab = newTab
            }
            updateOrientationLock()
        }
        .onChange(of: showingCamera) { updateOrientationLock() }
        .onAppear { updateOrientationLock() }
        .onDisappear { AppOrientation.setPortraitLocked(false) }
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            // Camera has fully dismissed — now safe to present the library sheet
            if let pending = pendingLibraryPhotos {
                libraryPhotos = pending
                pendingLibraryPhotos = nil
            }
        }) {
            CameraView { captures in
                // Multi-photo session complete
                guard !captures.isEmpty else { return }
                sessionCaptures = captures
            } onLibraryPhotosPicked: { photos in
                guard !photos.isEmpty else { return }
                // Stash photos and dismiss camera — the onDismiss callback
                // will present CreateLocationView after the animation completes
                pendingLibraryPhotos = photos
                showingCamera = false
            }
        }
        // Camera session → CreateLocationView
        .sheet(isPresented: Binding(
            get: { sessionCaptures != nil },
            set: { if !$0 { sessionCaptures = nil } }
        )) {
            if let captures = sessionCaptures {
                let firstLocation = captures.first?.location
                CreateLocationView(
                    sessionCaptures: captures,
                    photoLocation: firstLocation
                ) { location in
                    locationStore.addLocation(location)
                    CameraView.cleanupTempFiles()
                }
            }
        }
        // Library → CreateLocationView
        .sheet(isPresented: Binding(
            get: { libraryPhotos != nil },
            set: { if !$0 { libraryPhotos = nil } }
        )) {
            if let photos = libraryPhotos {
                // Use GPS from the first photo that has it, not just the first photo
                let gps = photos.compactMap({ $0.gpsCoordinate }).first
                let clLocation: CLLocation? = if let gps {
                    CLLocation(latitude: gps.lat, longitude: gps.lng)
                } else {
                    nil
                }
                CreateLocationView(
                    libraryPhotos: photos,
                    photoLocation: clLocation
                ) { location in
                    locationStore.addLocation(location)
                }
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

#Preview {
    ContentView()
}
