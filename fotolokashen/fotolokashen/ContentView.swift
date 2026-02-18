import SwiftUI
import CoreLocation

// MARK: - Brand Colors
extension Color {
    static let brandPurple = Color(red: 0.36, green: 0.30, blue: 1.0)  // #5B4CFF
    static let brandPurpleDark = Color(red: 0.30, green: 0.25, blue: 0.90)
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
                                Text("Login with Safari")
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
                    
                    Text("Opens Safari for secure login")
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
