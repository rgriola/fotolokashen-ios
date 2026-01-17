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
    init() {
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        
        // Set icon colors
        appearance.stackedLayoutAppearance.normal.iconColor = .black
        appearance.stackedLayoutAppearance.selected.iconColor = .black
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            LocationListView()
                .tabItem {
                    Label("Locations", systemImage: "list.bullet")
                }
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
        }
        .accentColor(.black)
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
