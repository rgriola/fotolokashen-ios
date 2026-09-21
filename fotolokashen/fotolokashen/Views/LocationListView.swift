import SwiftUI
import Combine
import CoreLocation
import UIKit

/// Main view for displaying a list of saved locations
struct LocationListView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var locationStore = LocationStore.shared
    @StateObject private var listViewModel = LocationListViewModel()
    @State private var searchText = ""
    @State private var selectedTypeFilter: String?
    @State private var sortOption: SortOption = .dateNewest
    
    // Delete confirmation state
    @State private var showingDeleteConfirmation = false
    @State private var locationToDelete: Location?
    @State private var isDeleting = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""

    // Group accordion state
    @State private var groups: [LocationGroup] = []
    @State private var expandedGroupIds: Set<Int> = []
    @State private var showGroupsOnly = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Friends / Public source toggles
                sourceToggleRow

                // Type filter chips
                typeFilterBar

                Group {
                    if locationStore.isLoading && locationStore.locations.isEmpty {
                        // Loading state with skeleton
                        skeletonLoadingView
                    } else if !locationStore.errorMessage.isEmpty && locationStore.locations.isEmpty {
                        // Load failed with nothing cached to show — offer a retry
                        errorStateView
                    } else if filteredAndSortedLocations.isEmpty {
                        // Empty state
                        emptyStateView
                    } else {
                        // Location list
                        locationList
                    }
                }
            }
            .navigationTitle("My Spots")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search")
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
                await listViewModel.refreshEnabledSources()
            }
        }
        .task {
            await locationStore.fetchLocations()
            await loadGroups()
        }
    }

    // MARK: - Source Toggle Row

    /// Friends' and public locations are additive (not mutually exclusive) — matches
    /// the Map screen's toggle semantics and the existing web/API merge behavior.
    private var sourceToggleRow: some View {
        HStack(spacing: 8) {
            sourceToggleButton(
                title: "Friends",
                systemImage: listViewModel.showFriends ? "person.2.fill" : "person.2",
                isOn: listViewModel.showFriends,
                isLoading: listViewModel.isLoadingFriends
            ) {
                Task { await listViewModel.toggleFriends() }
            }

            sourceToggleButton(
                title: "Public",
                systemImage: listViewModel.showPublic ? "globe.americas.fill" : "globe.americas",
                isOn: listViewModel.showPublic,
                isLoading: listViewModel.isLoadingPublic
            ) {
                Task { await listViewModel.togglePublic() }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func sourceToggleButton(
        title: String,
        systemImage: String,
        isOn: Bool,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isOn ? .white : .primary))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isOn ? Color.brand : Color(.systemGray5))
            .foregroundColor(isOn ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title) locations"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
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

                // Type chips from available types in the currently displayed locations
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

    /// Types that actually exist in the currently displayed (merged) locations
    private var availableTypeFilters: [String] {
        let types = Set(mergedLocations.compactMap { $0.location.type })
        // Return in the order defined by LocationTypeColors
        return LocationTypeColors.allTypes.filter { types.contains($0) }
    }

    // MARK: - Merged Locations

    /// Own locations merged with the currently-enabled friends/public sources, deduplicated by id
    private var mergedLocations: [LocationWithSource] {
        listViewModel.mergedLocations(own: locationStore.locations)
    }

    // MARK: - Filtered and Sorted Locations
    
    private var filteredAndSortedLocations: [LocationWithSource] {
        var locations = mergedLocations
        
        // Apply search filter
        if !searchText.isEmpty {
            locations = locations.filter { matchesSearch($0.location, query: searchText) }
        }
        
        // Apply type filter
        if let typeFilter = selectedTypeFilter {
            locations = locations.filter { $0.location.type == typeFilter }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateNewest:
            locations.sort { ($0.location.createdDate ?? Date.distantPast) > ($1.location.createdDate ?? Date.distantPast) }
        case .dateOldest:
            locations.sort { ($0.location.createdDate ?? Date.distantPast) < ($1.location.createdDate ?? Date.distantPast) }
        case .nameAZ:
            locations.sort { $0.location.name.localizedCaseInsensitiveCompare($1.location.name) == .orderedAscending }
        case .nameZA:
            locations.sort { $0.location.name.localizedCaseInsensitiveCompare($1.location.name) == .orderedDescending }
        }
        
        return locations
    }

    /// Checks name (title), city, address, caption (description), tags, and owner — so
    /// searching finds friends'/public locations by more than just their title.
    private func matchesSearch(_ location: Location, query: String) -> Bool {
        if location.name.localizedCaseInsensitiveContains(query) { return true }
        if let city = location.city, city.localizedCaseInsensitiveContains(query) { return true }
        if let address = location.address, address.localizedCaseInsensitiveContains(query) { return true }
        if let caption = location.caption, caption.localizedCaseInsensitiveContains(query) { return true }
        if let tags = location.tags, tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        if let creator = location.creator {
            if let username = creator.username, username.localizedCaseInsensitiveContains(query) { return true }
            let fullName = [creator.firstName, creator.lastName].compactMap { $0 }.joined(separator: " ")
            if !fullName.isEmpty, fullName.localizedCaseInsensitiveContains(query) { return true }
        }
        return false
    }
    
    // MARK: - Location List
    
    private var locationList: some View {
        List {
            // ── Grouped locations (accordion sections, own locations only) ─
            if !groups.isEmpty {
                ForEach(displayedGroups) { group in
                    Section {
                        if expandedGroupIds.contains(group.id) {
                            let groupLocations = locationsForGroup(group.id)
                            ForEach(groupLocations) { location in
                                NavigationLink {
                                    LocationDetailView(location: location)
                                } label: {
                                    LocationRow(location: location)
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 32, bottom: 4, trailing: 16))
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
                        }
                    } header: {
                        GroupAccordionHeader(
                            group: group,
                            locationCount: locationsForGroup(group.id).count,
                            isExpanded: expandedGroupIds.contains(group.id)
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if expandedGroupIds.contains(group.id) {
                                    expandedGroupIds.remove(group.id)
                                } else {
                                    expandedGroupIds.insert(group.id)
                                }
                            }
                        }
                    }
                }
            }

            // ── Ungrouped locations (own + friends' + public) ──────────
            if !showGroupsOnly {
                ForEach(ungroupedLocations) { item in
                    NavigationLink {
                        destinationView(for: item)
                    } label: {
                        LocationRow(location: item.location, showAttribution: item.source != .own)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if item.source == .own {
                            Button(role: .destructive) {
                                locationToDelete = item.location
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(isDeleting)
                        }
                    }
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

    // MARK: - Group Helpers

    private func loadGroups() async {
        do {
            groups = try await LocationGroupService.shared.fetchGroups()
        } catch {
            #if DEBUG
            print("[LocationListView] Failed to load groups: \(error)")
            #endif
        }
    }

    /// Groups that match current search/type filters
    private var displayedGroups: [LocationGroup] {
        groups.filter { group in
            !locationsForGroup(group.id).isEmpty
        }
    }

    /// Locations belonging to a specific group (own locations only — groups are owner-scoped)
    private func locationsForGroup(_ groupId: Int) -> [Location] {
        filteredAndSortedLocations.compactMap { item in
            item.source == .own && item.location.groupId == groupId ? item.location : nil
        }
    }

    /// Locations NOT in any group (own ungrouped + all friends'/public locations)
    private var ungroupedLocations: [LocationWithSource] {
        filteredAndSortedLocations.filter { $0.location.groupId == nil }
    }

    /// Read-only detail view for friends'/public locations; owner detail view for own locations
    @ViewBuilder
    private func destinationView(for item: LocationWithSource) -> some View {
        if let social = item.socialLocation {
            LocationDetailView(readOnlyContext: ReadOnlyLocationContext(socialLocation: social))
        } else {
            LocationDetailView(location: item.location)
        }
    }
    
    // MARK: - Error State

    private var errorStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Couldn't Load Locations")
                .font(.title2)
                .fontWeight(.semibold)

            Text(locationStore.errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task { await locationStore.refreshLocations() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
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
