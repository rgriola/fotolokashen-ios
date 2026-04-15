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
                
                Text("Location Scouting Made Simple")
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
    @State private var deepLinkLocation: Location?
    @State private var showDeepLinkDetail = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Locations list
            LocationListView()
                .tabItem {
                    Label("Locations", systemImage: "list.bullet")
                }
                .tag(0)

            // Map
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)

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

struct PhotoCapture: Identifiable {
    let id = UUID()
    let image: UIImage
    let location: CLLocation?
}

#Preview {
    ContentView()
}
