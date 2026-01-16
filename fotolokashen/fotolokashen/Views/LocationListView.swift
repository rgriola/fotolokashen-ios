import SwiftUI
import Combine
import CoreLocation

/// Main view for displaying a list of saved locations
struct LocationListView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = LocationListViewModel()
    @State private var showingCamera = false
    @State private var showingLogoutConfirmation = false
    @State private var capturedPhoto: PhotoCapture?
    @State private var searchText = ""
    @State private var selectedTypeFilter: String?
    @State private var sortOption: SortOption = .dateNewest
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.locations.isEmpty {
                    // Loading state with skeleton
                    skeletonLoadingView
                } else if filteredAndSortedLocations.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Location list
                    locationList
                }
            }
            .navigationTitle("My Locations")
            .searchable(text: $searchText, prompt: "Search locations")
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
                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            Label("Newest First", systemImage: "calendar.badge.clock")
                                .tag(SortOption.dateNewest)
                            Label("Oldest First", systemImage: "calendar")
                                .tag(SortOption.dateOldest)
                            Label("Name A-Z", systemImage: "textformat.abc")
                                .tag(SortOption.nameAZ)
                            Label("Name Z-A", systemImage: "textformat.abc")
                                .tag(SortOption.nameZA)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
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
                CameraView { image, location in
                    capturedPhoto = PhotoCapture(image: image, location: location)
                }
            }
            .sheet(item: $capturedPhoto) { capture in
                CreateLocationView(
                    photo: capture.image,
                    photoLocation: capture.location
                ) { location in
                    // Location created - refresh list
                    Task {
                        await viewModel.fetchLocations()
                    }
                }
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
    
    // MARK: - Filtered and Sorted Locations
    
    private var filteredAndSortedLocations: [Location] {
        var locations = viewModel.locations
        
        // Apply search filter
        if !searchText.isEmpty {
            locations = locations.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText) ||
                (location.address?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply type filter
        if let typeFilter = selectedTypeFilter {
            locations = locations.filter { $0.type == typeFilter }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateNewest:
            locations.sort { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .dateOldest:
            locations.sort { ($0.createdDate ?? Date.distantPast) < ($1.createdDate ?? Date.distantPast) }
        case .nameAZ:
            locations.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            locations.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
        
        return locations
    }
    
    // MARK: - Location List
    
    private var locationList: some View {
        List {
            ForEach(filteredAndSortedLocations) { location in
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
            Image(systemName: searchText.isEmpty ? "mappin.slash" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(searchText.isEmpty ? "No Locations Yet" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? "Start by capturing a photo with the camera" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if searchText.isEmpty {
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
        }
        .padding()
    }
    
    // MARK: - Skeleton Loading
    
    private var skeletonLoadingView: some View {
        List {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonLocationRow()
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Skeleton Row

struct SkeletonLocationRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Skeleton thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .shimmer(isAnimating: isAnimating)
            
            VStack(alignment: .leading, spacing: 8) {
                // Skeleton name
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 16)
                    .shimmer(isAnimating: isAnimating)
                
                // Skeleton address
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 14)
                    .shimmer(isAnimating: isAnimating)
                
                // Skeleton badge
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 24)
                    .shimmer(isAnimating: isAnimating)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.overlay(
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.3),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: isAnimating ? 200 : -200)
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
        )
        .clipped()
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case nameAZ = "Name A-Z"
    case nameZA = "Name Z-A"
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
