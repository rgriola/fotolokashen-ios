import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack {
            if authService.isAuthenticated {
                LoggedInView()
            } else {
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
    @EnvironmentObject var authService: AuthService
    @State private var showingCamera = false
    @State private var photoToCreate: PhotoCapture?
    @State private var createdLocations: [Location] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Logged In!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let user = authService.currentUser {
                VStack(spacing: 8) {
                    Text("Email: \(user.email)")
                        .font(.body)
                    
                    Text("Username: @\(user.username)")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("User ID: \(user.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            Button(action: {
                showingCamera = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(width: 60, height: 60)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.horizontal)
            
            if !createdLocations.isEmpty {
                VStack(spacing: 8) {
                    Text("Locations Created: \(createdLocations.count)")
                        .font(.headline)
                    
                    ForEach(createdLocations) { location in
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(location.type ?? "Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.3f, %.3f", location.lat, location.lng))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await authService.logout()
                }
            }) {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.right.square.fill")
                        Text("Logout")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authService.isLoading)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingCamera) {
            CameraView { image, location in
                photoToCreate = PhotoCapture(image: image, location: location)
            }
        }
        .sheet(item: $photoToCreate) { capture in
            CreateLocationView(
                photo: capture.image,
                photoLocation: capture.location
            ) { location in
                createdLocations.append(location)
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
