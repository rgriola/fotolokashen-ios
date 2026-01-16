import SwiftUI
import Combine

/// Main view for displaying a list of saved locations
struct LocationListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = LocationListViewModel()
    @State private var showingCamera = false
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.locations.isEmpty {
                    // Loading state
                    ProgressView("Loading locations...")
                } else if viewModel.locations.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Location list
                    locationList
                }
            }
            .navigationTitle("My Locations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView()
            }
            .refreshable {
                await viewModel.fetchLocations()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    Task {
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
        .task {
            await viewModel.fetchLocations()
        }
    }
    
    // MARK: - Location List
    
    private var locationList: some View {
        List {
            ForEach(viewModel.locations) { location in
                NavigationLink {
                    LocationDetailView(location: location)
                } label: {
                    LocationRow(location: location)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteLocation(location)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            // Loading more indicator
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Locations Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start by capturing a photo with the camera")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingCamera = true
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - View Model

@MainActor
class LocationListViewModel: ObservableObject {
    @Published var locations: [Location] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let locationService = LocationService.shared
    private let config = ConfigLoader.shared
    
    /// Fetch all locations for the current user
    func fetchLocations() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if config.enableDebugLogging {
                print("[LocationList] Fetching locations...")
            }
            
            locations = try await locationService.fetchLocations()
            
            if config.enableDebugLogging {
                print("[LocationList] Fetched \(locations.count) locations")
            }
        } catch {
            if config.enableDebugLogging {
                print("[LocationList] Error fetching locations: \(error)")
            }
            
            errorMessage = "Failed to load locations: \(error.localizedDescription)"
            showError = true
        }
    }
    
    /// Delete a location
    func deleteLocation(_ location: Location) async {
        do {
            if config.enableDebugLogging {
                print("[LocationList] Deleting location: \(location.id)")
            }
            
            try await locationService.deleteLocation(id: location.id)
            
            // Remove from local array
            locations.removeAll { $0.id == location.id }
            
            if config.enableDebugLogging {
                print("[LocationList] Location deleted successfully")
            }
        } catch {
            if config.enableDebugLogging {
                print("[LocationList] Error deleting location: \(error)")
            }
            
            errorMessage = "Failed to delete location: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Preview

#Preview {
    LocationListView()
}
