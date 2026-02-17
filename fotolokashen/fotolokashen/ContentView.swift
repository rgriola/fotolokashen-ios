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
    var body: some View {
        TabView {
            // Locations list
            LocationListView()
                .tabItem {
                    Label("Locations", systemImage: "list.bullet")
                }

            // Map
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            // Center camera tab - capture new locations
            CaptureTabView()
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }

            // Profile
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }

            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.brandPurple)
    }
}

// MARK: - Capture Tab View (Camera Center Tab)

struct CaptureTabView: View {
    @ObservedObject private var locationStore = LocationStore.shared
    @State private var showingCamera = false
    @State private var capturedPhoto: PhotoCapture?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Brand purple background
                Color.brandPurple
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Camera icon with crosshair style
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        
                        // Crosshair marks
                        VStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 3, height: 20)
                            Spacer()
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 3, height: 20)
                        }
                        .frame(height: 160)
                        
                        HStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 20, height: 3)
                            Spacer()
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 20, height: 3)
                        }
                        .frame(width: 160)
                    }
                    .frame(width: 160, height: 160)
                    
                    Text("Capture Location")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Take a photo to save a new\nproduction location")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    // Capture button
                    Button {
                        showingCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Open Camera")
                        }
                        .font(.headline)
                        .foregroundColor(.brandPurple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingCamera) {
                CameraView { image, location in
                    capturedPhoto = PhotoCapture(image: image, location: location)
                }
            }
            .sheet(item: $capturedPhoto) { capture in
                CreateLocationView(
                    photo: capture.image,
                    photoLocation: capture.location
                ) { location in
                    // Location created - add to shared store
                    locationStore.addLocation(location)
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
