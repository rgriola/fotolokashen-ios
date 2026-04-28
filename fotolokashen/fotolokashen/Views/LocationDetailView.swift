//
//  LocationDetailView.swift
//  fotolokashen
//
//  Created by Rodolfo Cesarotti on 1/16/26.
//
//  UNIFIED LOCATION DETAIL VIEW
//  Two modes: Owner (editable) and Read-only (viewing someone else's public location)
//  See copilot-instructions.md for usage patterns and initializer documentation.
//
// REVIEW: This file is ~750 lines — consider decomposing:
// 1. Extract owner-mode production detail sections into LocationDetailOwnerSections.swift
// 2. Extract read-only "Saved by" section into LocationDetailReadOnlySection.swift
// 3. Extract the visibility picker + toolbar logic into LocationDetailToolbar.swift
// 4. The formatDate/formatProductionDate helpers are duplicated — move to a shared Date extension.
//

import SwiftUI
import CoreLocation

// MARK: - LocationDetailView

struct LocationDetailView: View {

    // =========================================================================
    // MARK: - Properties
    // =========================================================================

    /// The location data being displayed
    /// In owner mode: this is the actual Location from user's saved locations
    /// In read-only mode: this is a synthesized Location from SocialLocation data
    @State private var currentLocation: Location

    /// Determines whether this is read-only (viewing someone else's location)
    /// - false = Owner mode: user can edit, change visibility
    /// - true = Read-only mode: viewing someone else's public location
    let isReadOnly: Bool

    /// Owner information (used in read-only mode to show "Saved by" section)
    let ownerUsername: String?
    let ownerDisplayName: String?

    /// The original SocialLocation ID (used for share URL in read-only mode)
    private let socialLocationId: Int?

    /// Inline photos from SocialLocation (used in read-only mode)
    private let inlinePhotos: [LocationPhoto]

    // =========================================================================
    // MARK: - Environment & State
    // =========================================================================

    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss

    /// Photos fetched from API (owner mode) or converted from inline (read-only)
    @State private var photos: [DetailPhoto] = []
    @State private var isLoadingPhotos = true
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingFullScreenGallery = false

    /// User save details (owner mode only - for showing metadata)
    @State private var userSaveDetails: UserSaveWithLocation?
    @State private var isLoadingDetails = true

    /// Edit mode state (owner mode only)
    @State private var showingEditView = false

    /// Visibility control state (owner mode only)
    @State private var locationVisibility: String
    @State private var isSavingVisibility = false

    /// Creator profile sheet (owner mode - when location was created by another user)
    @State private var showCreatorProfile = false

    // =========================================================================
    // MARK: - Initializers
    // =========================================================================

    /// OWNER MODE INITIALIZER
    /// Use this when displaying the user's own saved location
    /// - Parameter location: The Location from the user's saved locations
    init(location: Location) {
        self._currentLocation = State(initialValue: location)
        self.isReadOnly = false
        self.ownerUsername = nil
        self.ownerDisplayName = nil
        self.socialLocationId = nil
        self.inlinePhotos = []
        self._locationVisibility = State(initialValue: location.visibility ?? "private")
    }

    /// READ-ONLY MODE INITIALIZER
    /// Use this when displaying someone else's public location (from PublicProfileView)
    /// - Parameters:
    ///   - socialLocation: The SocialLocation from the public profile API
    ///   - ownerUsername: Username of the person who saved this location
    ///   - ownerDisplayName: Display name of the owner (firstName lastName or username)
    init(socialLocation: SocialLocation, ownerUsername: String, ownerDisplayName: String) {
        // Convert SocialLocation to Location for unified display
        let loc = socialLocation.location
        let synthesizedLocation = Location(
            id: loc.id,
            name: loc.name,
            address: loc.address ?? "",
            latitude: loc.lat,
            longitude: loc.lng,
            type: loc.type ?? "OTHER",
            placeId: loc.placeId ?? "",
            createdAt: socialLocation.savedAt ?? "",
            photosCount: loc.photos?.count ?? 0,
            thumbnailUrl: nil,
            userSaveId: nil,
            city: loc.city,
            state: loc.state,
            caption: socialLocation.caption
        )

        self._currentLocation = State(initialValue: synthesizedLocation)
        self.isReadOnly = true
        self.ownerUsername = ownerUsername
        self.ownerDisplayName = ownerDisplayName
        self.socialLocationId = socialLocation.id
        self.inlinePhotos = loc.photos ?? []
        self._locationVisibility = State(initialValue: "public") // Read-only = always public
    }

    /// READ-ONLY MODE INITIALIZER (from ReadOnlyLocationContext)
    /// Use this when navigating from Map after tapping a marker for a friend's location
    /// - Parameter context: The ReadOnlyLocationContext stored when navigating to map
    init(readOnlyContext context: ReadOnlyLocationContext) {
        self._currentLocation = State(initialValue: context.location)
        self.isReadOnly = true
        self.ownerUsername = context.ownerUsername
        self.ownerDisplayName = context.ownerDisplayName
        self.socialLocationId = context.id
        self.inlinePhotos = context.photos
        self._locationVisibility = State(initialValue: "public") // Read-only = always public
    }

    // =========================================================================
    // MARK: - Body
    // =========================================================================

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Photo Gallery with type badge overlay
                PhotoGallerySection(
                    photos: photos,
                    isLoading: isLoadingPhotos,
                    locationType: currentLocation.type,
                    latitude: currentLocation.latitude,
                    longitude: currentLocation.longitude,
                    isConnected: networkMonitor.isConnected,
                    selectedPhotoIndex: $selectedPhotoIndex,
                    showingFullScreenGallery: $showingFullScreenGallery
                )

                // =============================================================
                // Main Content
                // =============================================================
                VStack(alignment: .leading, spacing: 16) {

                    // ---------------------------------------------------------
                    // Location Name & Address
                    // ---------------------------------------------------------
                    locationHeaderSection

                    // ---------------------------------------------------------
                    // Visibility Control (OWNER MODE ONLY)
                    // Allows changing between Public/Unlisted/Private
                    // ---------------------------------------------------------
                    if !isReadOnly {
                        visibilityControlRow
                    }

                    // ---------------------------------------------------------
                    // Caption (if present)
                    // ---------------------------------------------------------
                    if let caption = currentLocation.caption, !caption.isEmpty {
                        captionSection(caption: caption)
                    }

                    Divider()

                    // ---------------------------------------------------------
                    // Production Details (OWNER MODE ONLY)
                    // Shows production date, notes, entry point, parking, etc.
                    // ---------------------------------------------------------
                    if !isReadOnly {
                        productionDetailsSection
                    }

                    // ---------------------------------------------------------
                    // "Saved by" Section (READ-ONLY MODE ONLY)
                    // Shows who saved this location
                    // ---------------------------------------------------------
                    if isReadOnly, let username = ownerUsername, let displayName = ownerDisplayName {
                        savedBySection(username: username, displayName: displayName)
                    }

                    // ---------------------------------------------------------
                    // Location ID (OWNER MODE ONLY - for support)
                    // ---------------------------------------------------------
                    if !isReadOnly {
                        Spacer(minLength: 32)
                        locationIdFooter
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(currentLocation.name)
        // ---------------------------------------------------------------------
        // Toolbar
        // ---------------------------------------------------------------------
        .toolbar {
            // OWNER MODE: Edit + Share buttons
            if !isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        // Share button (uses creator's username from location)
                        if let username = currentLocation.creator?.username,
                           let url = URL(string: "https://fotolokashen.com/\(username)/locations/\(currentLocation.id)") {
                            ShareLink(
                                item: url,
                                subject: Text(currentLocation.name),
                                message: Text(currentLocation.address ?? "")
                            ) {
                                Image(systemName: AppIcons.share)
                            }
                        }

                        // Edit button
                        Button {
                            showingEditView = true
                        } label: {
                            Image(systemName: AppIcons.edit)
                        }
                    }
                }
            }

            // READ-ONLY MODE: Share button only (uses owner's username)
            if isReadOnly, let username = ownerUsername, let locId = socialLocationId,
               let url = URL(string: "https://fotolokashen.com/\(username)/locations/\(locId)") {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: url,
                        subject: Text(currentLocation.name),
                        message: Text(currentLocation.address ?? "")
                    ) {
                        Image(systemName: AppIcons.share)
                    }
                }
            }
        }
        // ---------------------------------------------------------------------
        // Sheets
        // ---------------------------------------------------------------------
        .sheet(isPresented: $showingEditView) {
            // Edit location sheet (owner mode)
            EditLocationView(location: currentLocation) { updated in
                currentLocation = updated
                Task {
                    await loadPhotos()
                    await loadUserSaveDetails()
                }
            }
        }
        .sheet(isPresented: $showCreatorProfile) {
            // Creator profile sheet (when viewing location created by another user)
            if let creator = userSaveDetails?.location.creator?.username {
                NavigationStack {
                    PublicProfileView(username: creator)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showCreatorProfile = false }
                            }
                        }
                }
            }
        }
        // ---------------------------------------------------------------------
        // Full Screen Gallery
        // ---------------------------------------------------------------------
        .fullScreenCover(isPresented: $showingFullScreenGallery) {
            PhotoGalleryFullScreen(
                photos: photos,
                selectedIndex: $selectedPhotoIndex
            )
        }
        // ---------------------------------------------------------------------
        // Data Loading on Appear
        // ---------------------------------------------------------------------
        .task {
            await loadPhotos()
            if !isReadOnly {
                await loadUserSaveDetails()
            }
        }
    }



    // =========================================================================
    // MARK: - Location Header Section
    // =========================================================================

    /// Location name, address, and creator info
    private var locationHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Location name
            Text(currentLocation.name)
                .font(.title2)
                .fontWeight(.bold)

            // Address with map pin icon - tap to show on map
            if let address = currentLocation.address, !address.isEmpty {
                Button {
                    showOnMap()
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: AppIcons.mapPin)
                            .foregroundColor(.destructive)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            // City/State (if available - commonly in read-only mode)
            if let cityState = formatCityState() {
                HStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .foregroundColor(.secondary)
                    Text(cityState)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Created date + creator link (owner mode only)
            if !isReadOnly {
                HStack(spacing: 4) {
                    Text("Added \(formatDate(currentLocation.createdAt))")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    // Show creator if different from current user
                    if let creator = userSaveDetails?.location.creator?.username {
                        Text("by")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button {
                            showCreatorProfile = true
                        } label: {
                            Text("@\(creator)")
                                .font(.footnote)
                                .foregroundColor(.brandPurple)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Caption Section
    // =========================================================================

    private func captionSection(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Caption")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(caption)
                .font(.body)
        }
        .padding(.top, 4)
    }

    // =========================================================================
    // MARK: - Visibility Control (OWNER MODE ONLY)
    // =========================================================================

    /// Dropdown menu for changing location visibility
    /// Only shown in owner mode
    private var visibilityControlRow: some View {
        HStack {
            if isSavingVisibility {
                ProgressView()
                    .scaleEffect(0.75)
                    .frame(height: 28)
            } else {
                Menu {
                    Button(action: { changeVisibility("public") }) {
                        Label("Public — Anyone can view", systemImage: "globe")
                    }
                    Button(action: { changeVisibility("unlisted") }) {
                        Label("Unlisted — Only with link", systemImage: "link")
                    }
                    Button(action: { changeVisibility("private") }) {
                        Label("Private — Only you", systemImage: "lock.fill")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: visibilityIcon(for: locationVisibility))
                            .font(.caption)
                        Text(visibilityLabel(for: locationVisibility))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(visibilityColor(for: locationVisibility))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(visibilityColor(for: locationVisibility).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // =========================================================================
    // MARK: - Production Details Section (OWNER MODE ONLY)
    // =========================================================================

    /// Shows production date, notes, entry point, parking, access, etc.
    /// Only shown in owner mode
    @ViewBuilder
    private var productionDetailsSection: some View {
        Group {
            if let date = currentLocation.productionDate {
                DetailRow(label: "Production Date", value: formatProductionDate(date))
            }
            if let details = currentLocation.details, !details.isEmpty {
                DetailRow(label: "Location Details", value: details)
            }
            if let notes = currentLocation.productionNotes, !notes.isEmpty {
                DetailRow(label: "Production Notes", value: notes)
            }
            if let entry = currentLocation.entryPoint, !entry.isEmpty {
                DetailRow(label: "Entry Point", value: entry)
            }
            if let parking = currentLocation.parking, !parking.isEmpty {
                DetailRow(label: "Parking", value: parking)
            }
            if let access = currentLocation.access, !access.isEmpty {
                DetailRow(label: "Access", value: access)
            }
        }

        // Additional metadata
        Group {
            if let bestTime = currentLocation.bestTimeOfDay, !bestTime.isEmpty {
                DetailRow(label: "Best Time of Day", value: bestTime)
            }
            if let contact = currentLocation.contactPerson, !contact.isEmpty {
                DetailRow(label: "Contact Person", value: contact)
            }
            if let phone = currentLocation.contactPhone, !phone.isEmpty {
                DetailRow(label: "Contact Phone", value: phone)
            }
            if let hours = currentLocation.operatingHours, !hours.isEmpty {
                DetailRow(label: "Operating Hours", value: hours)
            }
            if let permitCost = currentLocation.permitCost {
                DetailRow(label: "Permit Cost", value: String(format: "$%.2f", permitCost))
            }
            if let permitRequired = currentLocation.permitRequired {
                DetailRow(label: "Permit Required", value: permitRequired ? "Yes" : "No")
            }
            if let restrictions = currentLocation.restrictions, !restrictions.isEmpty {
                DetailRow(label: "Restrictions", value: restrictions)
            }
        }
    }

    // =========================================================================
    // MARK: - "Saved by" Section (READ-ONLY MODE ONLY)
    // =========================================================================

    /// Shows who saved this location
    /// Only shown in read-only mode when viewing someone else's location
    private func savedBySection(username: String, displayName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(Color.brandPurple.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.brandPurple)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    // =========================================================================
    // MARK: - Location ID Footer (OWNER MODE ONLY)
    // =========================================================================

    /// Shows location ID for support purposes
    private var locationIdFooter: some View {
        HStack {
            Text("Location ID: \(currentLocation.id)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            Spacer()
        }
    }



    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    /// Loads photos for this location
    /// - Owner mode: fetches from /api/locations/{id}/photos
    /// - Read-only mode: converts inline photos from SocialLocation, or fetches from user's public locations if empty
    private func loadPhotos() async {
        if isReadOnly {
            // Read-only mode: use inline photos from SocialLocation
            if !inlinePhotos.isEmpty {
                await MainActor.run {
                    self.photos = DetailPhoto.fromLocationPhotos(inlinePhotos)
                    self.isLoadingPhotos = false
                }
            } else if let username = ownerUsername, !username.isEmpty {
                // No inline photos - fetch from user's public locations to get photos
                await fetchPhotosFromPublicProfile(username: username)
            } else {
                await MainActor.run {
                    self.isLoadingPhotos = false
                }
            }
        } else {
            // Owner mode: fetch from API
            let locationId = currentLocation.id

            do {
                let response: PhotosResponse = try await APIClient.shared.get("/api/locations/\(locationId)/photos")
                await MainActor.run {
                    self.photos = response.photos
                    self.isLoadingPhotos = false
                }
            } catch {
                #if DEBUG
                print("[LocationDetailView] Failed to load photos: \(error)")
                #endif
                await MainActor.run {
                    self.photos = DetailPhoto.fromLocationPhotos(currentLocation.photos ?? [])
                    self.isLoadingPhotos = false
                }
            }
        }
    }

    /// Fetches photos from user's public locations when inline photos are empty
    /// Used when tapping a friend's marker on the map (MapSocialLocation doesn't include photos)
    private func fetchPhotosFromPublicProfile(username: String) async {
        do {
            let response: UserLocationsResponse = try await APIClient.shared.get(
                "/api/v1/users/\(username)/locations",
                authenticated: true
            )

            // Find the matching location by ID
            let locationId = socialLocationId ?? currentLocation.id
            if let matchingLocation = response.locations.first(where: { $0.location.id == locationId }) {
                await MainActor.run {
                    self.photos = DetailPhoto.fromLocationPhotos(matchingLocation.location.photos ?? [])
                    self.isLoadingPhotos = false
                }
            } else {
                #if DEBUG
                print("[LocationDetailView] Location \(locationId) not found in user's public locations")
                #endif
                await MainActor.run {
                    self.isLoadingPhotos = false
                }
            }
        } catch {
            #if DEBUG
            print("[LocationDetailView] Failed to fetch photos from public profile: \(error)")
            #endif
            await MainActor.run {
                self.isLoadingPhotos = false
            }
        }
    }

    /// Loads user save details (owner mode only)
    /// Provides additional metadata like creator info
    private func loadUserSaveDetails() async {
        guard let userSaveId = currentLocation.userSaveId else {
            await MainActor.run { isLoadingDetails = false }
            return
        }

        do {
            let response: UserSaveDetailResponse = try await APIClient.shared.get("/api/locations/\(userSaveId)")
            await MainActor.run {
                self.userSaveDetails = response.userSave
                self.isLoadingDetails = false
            }
        } catch {
            #if DEBUG
            print("[LocationDetailView] Failed to load user save details: \(error)")
            #endif
            await MainActor.run { isLoadingDetails = false }
        }
    }

    // =========================================================================
    // MARK: - Visibility Helpers
    // =========================================================================

    private func visibilityIcon(for visibility: String) -> String {
        switch visibility.lowercased() {
        case "public": return "globe"
        case "unlisted": return "person.2"
        default: return "lock"
        }
    }

    private func visibilityLabel(for visibility: String) -> String {
        switch visibility {
        case "public": return "Public"
        case "unlisted": return "Unlisted"
        default: return "Private"
        }
    }

    private func visibilityColor(for visibility: String) -> Color {
        switch visibility {
        case "public": return .green
        case "unlisted": return .orange
        default: return Color(.systemGray)
        }
    }

    private func changeVisibility(_ newVisibility: String) {
        guard newVisibility != locationVisibility else { return }
        let previous = locationVisibility
        locationVisibility = newVisibility
        Task {
            isSavingVisibility = true
            var request = UpdateLocationRequest()
            request.visibility = newVisibility
            if let updated = await LocationStore.shared.updateLocation(currentLocation, request: request) {
                await MainActor.run {
                    currentLocation = updated
                    locationVisibility = updated.visibility ?? "private"
                    isSavingVisibility = false
                }
            } else {
                await MainActor.run {
                    locationVisibility = previous
                    isSavingVisibility = false
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Formatting Helpers
    // =========================================================================

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return isoString
    }

    private func formatProductionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func formatCityState() -> String? {
        let parts = [currentLocation.city, currentLocation.state].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Navigate to Map tab and center on this location's pin
    /// In read-only mode, creates a ReadOnlyLocationContext so MapView shows full LocationDetailView
    private func showOnMap() {
        if isReadOnly {
            // Read-only mode: Create context so MapView can show full LocationDetailView
            let context = ReadOnlyLocationContext(
                id: socialLocationId ?? currentLocation.id,
                location: currentLocation,
                ownerUsername: ownerUsername ?? "",
                ownerDisplayName: ownerDisplayName ?? "",
                photos: inlinePhotos
            )
            LocationStore.shared.mapFocusReadOnlyContext = context
        } else {
            // Owner mode: Use regular location focus
            LocationStore.shared.mapFocusLocation = currentLocation
        }

        // Dismiss this view
        dismiss()
        // Navigate to Map tab
        NotificationCenter.default.post(name: .navigateToMapTab, object: nil)
    }
}

// MARK: - Preview

#Preview("Owner Mode") {
    NavigationStack {
        LocationDetailView(location: Location(
            id: 1,
            name: "Test Location",
            address: "123 Main St, New York, NY 10001",
            latitude: 40.7128,
            longitude: -74.0060,
            type: "BROLL",
            placeId: "place-123",
            createdAt: "2026-01-20T10:00:00Z",
            photosCount: 3,
            thumbnailUrl: nil,
            userSaveId: 1
        ))

    }
}
