//
//  LocationDetailView.swift
//  fotolokashen
//
//  Created by Rodolfo Cesarotti on 1/16/26.
//
//  ============================================================================
//  UNIFIED LOCATION DETAIL VIEW
//  ============================================================================
//
//  This view handles TWO modes of displaying location details:
//
//  1. OWNER MODE (isReadOnly = false):
//     - User is viewing their OWN saved location
//     - Shows edit button in toolbar → opens EditLocationView
//     - Shows visibility control (Public/Unlisted/Private dropdown)
//     - Full production details (notes, entry point, parking, access, etc.)
//     - Photos loaded from `/api/locations/{id}/photos` endpoint
//     - Location ID shown at bottom for support
//
//  2. READ-ONLY MODE (isReadOnly = true):
//     - User is viewing SOMEONE ELSE's public location (from PublicProfileView)
//     - NO edit button, NO visibility control
//     - Shows "Saved by" section with owner avatar + username
//     - Photos inline from SocialLocation model (no additional API call)
//     - Share button generates URL to owner's public profile page
//
//  HOW TO USE:
//  -----------
//  // Owner mode (user's own location):
//  LocationDetailView(location: myLocation)
//
//  // Read-only mode (viewing someone else's location):
//  LocationDetailView(
//      socialLocation: socialLoc,
//      ownerUsername: "johndoe",
//      ownerDisplayName: "John Doe"
//  )
//
//  ============================================================================

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

    @EnvironmentObject var networkMonitor: NetworkMonitor
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

    // =========================================================================
    // MARK: - Body
    // =========================================================================

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // =============================================================
                // Photo Gallery with type badge overlay
                // Shows photos in a swipeable TabView
                // =============================================================
                ZStack(alignment: .topLeading) {
                    photoGallerySection

                    // Type badge (category like BROLL, STORY, etc.)
                    if let type = currentLocation.type, !type.isEmpty {
                        typeBadge(type: type)
                            .padding(12)
                    }
                }

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
    // MARK: - Photo Gallery Section
    // =========================================================================

    /// Displays photos in a swipeable gallery, or falls back to map/placeholder
    @ViewBuilder
    private var photoGallerySection: some View {
        if isLoadingPhotos {
            // Loading state - show progress indicator
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                ProgressView()
                    .scaleEffect(1.5)
            }
        } else if !photos.isEmpty {
            // Photo gallery - swipeable TabView
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    AsyncImage(url: URL(string: photo.url)) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                ProgressView()
                            }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .onTapGesture {
                                    selectedPhotoIndex = index
                                    showingFullScreenGallery = true
                                }
                        case .failure:
                            ZStack {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 300)
            .clipped()

            // Photo counter badge
            HStack {
                Spacer()
                Text("\(selectedPhotoIndex + 1) / \(photos.count)")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top, -35)
            .padding(.bottom, 10)
        } else if networkMonitor.isConnected {
            // No photos - show Google Maps static image
            googleMapsStaticImageSection
        } else {
            // Offline - show placeholder
            offlinePlaceholder
        }
    }

    // =========================================================================
    // MARK: - Type Badge
    // =========================================================================

    /// Badge showing the location type (BROLL, STORY, etc.)
    private func typeBadge(type: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: LocationTypeColors.icon(for: type))
                .font(.caption)
            Text(type)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LocationTypeColors.color(for: type))
        .clipShape(Capsule())
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
                            .foregroundColor(.red)
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
    // MARK: - Google Maps Static Image (Fallback when no photos)
    // =========================================================================

    private var googleMapsStaticImageSection: some View {
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        let mapUrl = "https://maps.googleapis.com/maps/api/staticmap?center=\(currentLocation.latitude),\(currentLocation.longitude)&zoom=16&size=600x300&maptype=roadmap&markers=color:red%7C\(currentLocation.latitude),\(currentLocation.longitude)&key=\(apiKey)"

        return AsyncImage(url: URL(string: mapUrl)) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 200)
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "photo.badge.exclamationmark")
                                Text("No photos available")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 8)
                        }
                    )
            case .failure:
                offlinePlaceholder
            @unknown default:
                EmptyView()
            }
        }
    }

    // =========================================================================
    // MARK: - Offline Placeholder
    // =========================================================================

    private var offlinePlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 200)

            VStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("No connection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Photos will load when online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // =========================================================================
    // MARK: - Data Loading
    // =========================================================================

    /// Loads photos for this location
    /// - Owner mode: fetches from /api/locations/{id}/photos
    /// - Read-only mode: converts inline photos from SocialLocation
    private func loadPhotos() async {
        if isReadOnly {
            // Read-only mode: use inline photos from SocialLocation
            await MainActor.run {
                self.photos = inlinePhotos.map { photo in
                    DetailPhoto(
                        id: photo.id,
                        imagekitFilePath: photo.imagekitFilePath,
                        url: "https://ik.imagekit.io/rgriola\(photo.imagekitFilePath)",
                        thumbnailUrl: "https://ik.imagekit.io/rgriola\(photo.imagekitFilePath)?tr=w-400,h-400",
                        caption: nil,
                        width: nil,
                        height: nil,
                        uploadedAt: nil,
                        gpsLatitude: nil,
                        gpsLongitude: nil,
                        isPrimary: photo.isPrimary,
                        fileSize: nil,
                        mimeType: nil
                    )
                }
                self.isLoadingPhotos = false
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
                    // Use embedded photos as fallback
                    self.photos = (currentLocation.photos ?? []).map { photo in
                        DetailPhoto(
                            id: photo.id,
                            imagekitFilePath: photo.imagekitFilePath,
                            url: "https://ik.imagekit.io/rgriola\(photo.imagekitFilePath)",
                            thumbnailUrl: "https://ik.imagekit.io/rgriola\(photo.imagekitFilePath)?tr=w-400,h-400",
                            caption: nil,
                            width: nil,
                            height: nil,
                            uploadedAt: nil,
                            gpsLatitude: nil,
                            gpsLongitude: nil,
                            isPrimary: photo.isPrimary,
                            fileSize: nil,
                            mimeType: nil
                        )
                    }
                    self.isLoadingPhotos = false
                }
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
    private func showOnMap() {
        // Set the location to focus on in the map
        LocationStore.shared.mapFocusLocation = currentLocation
        // Dismiss this view
        dismiss()
        // Navigate to Map tab
        NotificationCenter.default.post(name: .navigateToMapTab, object: nil)
    }
}

// MARK: - Supporting Types

/// Response from /api/locations/{id}/photos
struct PhotosResponse: Codable {
    let photos: [DetailPhoto]
    let pagination: PhotoPagination?
}

struct PhotoPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

/// Detailed photo information from API
struct DetailPhoto: Codable, Identifiable {
    let id: Int
    let imagekitFilePath: String
    let url: String
    let thumbnailUrl: String
    let caption: String?
    let width: Int?
    let height: Int?
    let uploadedAt: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let isPrimary: Bool?
    let fileSize: Int?
    let mimeType: String?
}

// MARK: - Section Header Component

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.brandPurple)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.top, 4)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Full Screen Photo Gallery

struct PhotoGalleryFullScreen: View {
    let photos: [DetailPhoto]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    AsyncImage(url: URL(string: photo.url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()

                // Photo info
                if !photos.isEmpty && selectedIndex < photos.count {
                    let photo = photos[selectedIndex]
                    VStack(spacing: 4) {
                        Text("\(selectedIndex + 1) of \(photos.count)")
                            .font(.headline)
                            .foregroundColor(.white)

                        if let caption = photo.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 40)
                }
            }
        }
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
        .environmentObject(NetworkMonitor.shared)
    }
}
