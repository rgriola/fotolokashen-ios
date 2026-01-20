import SwiftUI
import CoreLocation

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
        VStack(spacing: 30) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("fotolokashen")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("iOS Companion App")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(spacing: 15) {
                Button(action: {
                    authService.startLogin()
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "person.circle.fill")
                            Text("Login with Safari")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(authService.isLoading)
                
                Text("Opens Safari for secure login")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Backend: \(ConfigLoader.shared.backendBaseURL)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("OAuth Client: \(ConfigLoader.shared.oauthClientId)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .padding()
    }
}

// MARK: - Logged In View

struct LoggedInView: View {
    var body: some View {
        TabView {
            // Brand tab (left) - shows app info
            BrandTabView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            LocationListView()
                .tabItem {
                    Label("Locations", systemImage: "list.bullet")
                }
            
            // Center camera tab - capture new locations
            CaptureTabView()
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
        }
    }
}

// MARK: - Brand Tab View (App Icon Left Tab)

struct BrandTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // User info at top in grey
                if let user = authService.currentUser {
                    Text(user.username)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // App Icon - using the app's actual icon
                if let appIcon = UIImage(named: "AppIcon") {
                    Image(uiImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                } else {
                    // Fallback icon if AppIcon not found
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .frame(width: 120, height: 120)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                
                Text("fotolokashen")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Capture • Save • Explore")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Quick stats
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        Text("Save production locations with photos")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                        Text("Capture geo-tagged location photos")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.blue)
                        Text("View all locations on a map")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    Task {
                        LocationStore.shared.clear()
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
}

// MARK: - Capture Tab View (Camera Center Tab)

struct CaptureTabView: View {
    @ObservedObject private var locationStore = LocationStore.shared
    @State private var showingCamera = false
    @State private var capturedPhoto: PhotoCapture?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Camera icon
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                Text("Capture Location")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Take a photo to save a new production location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
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
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
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
