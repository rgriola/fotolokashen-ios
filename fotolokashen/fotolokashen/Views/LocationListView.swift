import SwiftUI
import Combine
import CoreLocation
import UIKit

/// Main view for displaying a list of saved locations
struct LocationListView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var locationStore = LocationStore.shared
    @State private var searchText = ""
    @State private var selectedTypeFilter: String?
    @State private var sortOption: SortOption = .dateNewest
    
    // Delete confirmation state
    @State private var showingDeleteConfirmation = false
    @State private var locationToDelete: Location?
    @State private var isDeleting = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter chips
                typeFilterBar

                Group {
                    if locationStore.isLoading && locationStore.locations.isEmpty {
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
            }
            .navigationTitle("My Locations")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search locations")
            .toolbar {
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
            }
            .refreshable {
                await locationStore.refreshLocations()
            }
        }
        .task {
            await locationStore.fetchLocations()
        }
    }

    // MARK: - Type Filter Bar

    /// Horizontal scrollable type filter chips
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                FilterChip(
                    label: "All",
                    icon: "mappin.circle",
                    isSelected: selectedTypeFilter == nil,
                    color: .gray
                ) {
                    selectedTypeFilter = nil
                }

                // Type chips from available types in user's locations
                ForEach(availableTypeFilters, id: \.self) { type in
                    FilterChip(
                        label: type,
                        icon: LocationTypeColors.icon(for: type),
                        isSelected: selectedTypeFilter == type,
                        color: LocationTypeColors.color(for: type)
                    ) {
                        selectedTypeFilter = selectedTypeFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    /// Types that actually exist in the user's locations
    private var availableTypeFilters: [String] {
        let types = Set(locationStore.locations.compactMap { $0.type })
        // Return in the order defined by LocationTypeColors
        return LocationTypeColors.allTypes.filter { types.contains($0) }
    }
    
    // MARK: - Filtered and Sorted Locations
    
    private var filteredAndSortedLocations: [Location] {
        var locations = locationStore.locations
        
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
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        locationToDelete = location
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(isDeleting)
                }
            }
            
            // Loading more indicator
            if locationStore.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .alert("Delete Location", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                locationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let location = locationToDelete {
                    deleteLocation(location)
                }
            }
        } message: {
            if let location = locationToDelete {
                Text("Are you sure you want to delete \"\(location.name)\"? This action cannot be undone.")
            }
        }
        .alert("Delete Failed", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }
    
    // MARK: - Delete Location
    
    private func deleteLocation(_ location: Location) {
        isDeleting = true
        
        Task {
            let success = await locationStore.deleteLocation(location)
            
            await MainActor.run {
                isDeleting = false
                locationToDelete = nil
                
                if success {
                    // Success haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } else {
                    // Error haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    deleteErrorMessage = locationStore.errorMessage.isEmpty 
                        ? "Unable to delete location. Please try again."
                        : locationStore.errorMessage
                    showingDeleteError = true
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "mappin.slash" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "No Locations Yet" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? "Go to the Capture tab to add your first location" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if searchText.isEmpty {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Use the Capture tab below")
                }
                .font(.headline)
                .foregroundColor(.brand)
                .padding(.top)
            }
        }
        .padding()
    }
    
    // MARK: - Skeleton Loading
    
    private var skeletonLoadingView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonLocationRow()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Skeleton Row

struct SkeletonLocationRow: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Skeleton photo area
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.systemFill))
                .frame(height: 180)
                .shimmer(isAnimating: isAnimating)

            VStack(alignment: .leading, spacing: 8) {
                // Skeleton name
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 180, height: 18)
                    .shimmer(isAnimating: isAnimating)
                
                // Skeleton address
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 220, height: 14)
                    .shimmer(isAnimating: isAnimating)

                // Skeleton bottom row
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(width: 40, height: 12)
                        .shimmer(isAnimating: isAnimating)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
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

// MARK: - Preview

#Preview {
    LocationListView()
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.25) : Color(.systemGray6))
            .foregroundColor(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
