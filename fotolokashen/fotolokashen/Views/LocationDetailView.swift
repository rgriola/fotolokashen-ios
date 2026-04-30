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
//  Phase 2a-1: data/lifecycle moved to `LocationDetailViewModel`. The view
//  now binds to the VM via `@StateObject` and is a thin presentation shell.
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - LocationDetailView

struct LocationDetailView: View {

    // =========================================================================
    // MARK: - Properties
    // =========================================================================

    @StateObject private var viewModel: LocationDetailViewModel

    // Convenience read-throughs to keep existing inline code readable.
    private var currentLocation: Location { viewModel.currentLocation }
    private var isReadOnly: Bool { viewModel.mode.isReadOnly }
    private var ownerUsername: String? { viewModel.mode.ownerUsername }
    private var ownerDisplayName: String? { viewModel.mode.ownerDisplayName }
    private var socialLocationId: Int? { viewModel.mode.socialLocationId }
    private var inlinePhotos: [LocationPhoto] { viewModel.mode.inlinePhotos }
    private var photos: [DetailPhoto] { viewModel.photos }
    private var isLoadingPhotos: Bool { viewModel.isLoadingPhotos }
    private var userSaveDetails: UserSaveWithLocation? { viewModel.userSaveDetails }
    private var locationVisibility: String { viewModel.locationVisibility }
    private var isSavingVisibility: Bool { viewModel.isSavingVisibility }

    // =========================================================================
    // MARK: - Environment & Local UI State
    // =========================================================================

    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss

    /// Photo gallery selection (UI-only, not persisted).
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingFullScreenGallery = false

    /// Edit/profile sheet presentation flags (UI-only).
    @State private var showingEditView = false
    @State private var showCreatorProfile = false

    // =========================================================================
    // MARK: - Initializers
    // =========================================================================

    /// OWNER MODE INITIALIZER
    /// Use this when displaying the user's own saved location
    /// - Parameter location: The Location from the user's saved locations
    init(location: Location) {
        _viewModel = StateObject(
            wrappedValue: LocationDetailViewModel(location: location, mode: .owner)
        )
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
        _viewModel = StateObject(
            wrappedValue: LocationDetailViewModel(
                location: synthesizedLocation,
                mode: .readOnly(
                    socialLocationId: socialLocation.id,
                    ownerUsername: ownerUsername,
                    ownerDisplayName: ownerDisplayName,
                    inlinePhotos: loc.photos ?? []
                )
            )
        )
    }

    /// READ-ONLY MODE INITIALIZER (from ReadOnlyLocationContext)
    /// Use this when navigating from Map after tapping a marker for a friend's location
    /// - Parameter context: The ReadOnlyLocationContext stored when navigating to map
    init(readOnlyContext context: ReadOnlyLocationContext) {
        _viewModel = StateObject(
            wrappedValue: LocationDetailViewModel(
                location: context.location,
                mode: .readOnly(
                    socialLocationId: context.id,
                    ownerUsername: context.ownerUsername,
                    ownerDisplayName: context.ownerDisplayName,
                    inlinePhotos: context.photos
                )
            )
        )
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
                    // Photo Spread Map (OWNER MODE ONLY)
                    // Shows where each photo was taken on a mini-map
                    // ---------------------------------------------------------
                    if !isReadOnly && !isLoadingPhotos {
                        let spreadMap = PhotoSpreadMapView(
                            locationCoordinate: currentLocation.coordinate,
                            photos: photos
                        )
                        if spreadMap.hasSpread {
                            Divider()
                            spreadMap
                        }
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
                Task { await viewModel.applyEdited(updated) }
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
            await viewModel.loadPhotos()
            if !isReadOnly {
                await viewModel.loadUserSaveDetails()
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

            // Postal-style address — tap to show on map
            if hasAddressContent {
                Button {
                    showOnMap()
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: AppIcons.mapPin)
                            .foregroundColor(.destructive)
                            .padding(.top, 2)

                        postalAddressBlock
                    }
                }
                .buttonStyle(PlainButtonStyle())
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
                                .foregroundColor(.brand)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Whether any address content is available to display
    private var hasAddressContent: Bool {
        let hasComponents = currentLocation.street != nil || currentLocation.city != nil
        let hasRawAddress = !(currentLocation.address ?? "").isEmpty
        return hasComponents || hasRawAddress
    }

    /// Structured postal address block
    /// Renders as:  30 Hudson Yards
    ///              New York, NY 10001
    @ViewBuilder
    private var postalAddressBlock: some View {
        let hasComponents = currentLocation.street != nil || currentLocation.city != nil

        if hasComponents {
            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Street (number + street name)
                if let streetLine = formatStreetLine() {
                    Text(streetLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Line 2: City, State ZIP
                if let cityLine = formatCityStateZip() {
                    Text(cityLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        } else if let address = currentLocation.address, !address.isEmpty {
            // Fallback: raw address string when components aren't available
            Text(address)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
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
                    Button(action: { viewModel.changeVisibility("public") }) {
                        Label("Public — Anyone can view", systemImage: "globe")
                    }
                    Button(action: { viewModel.changeVisibility("unlisted") }) {
                        Label("Unlisted — Only with link", systemImage: "link")
                    }
                    Button(action: { viewModel.changeVisibility("private") }) {
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
            if let permitRequired = currentLocation.permitRequired, permitRequired {
                DetailRow(label: "Permit Required", value: "Yes")
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
                    .fill(Color.brand.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.brand)
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
    // MARK: - Visibility Helpers (presentation-only)
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

    /// Formats street line: "30 Hudson Yards"
    private func formatStreetLine() -> String? {
        let parts = [currentLocation.number, currentLocation.street]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Formats city/state/zip line: "New York, NY 10001"
    private func formatCityStateZip() -> String? {
        var line = ""

        // City
        if let city = currentLocation.city, !city.isEmpty {
            line = city
        }

        // State (abbreviation)
        if let state = currentLocation.state, !state.isEmpty {
            let abbr = state.count == 2 ? state.uppercased() : state
            if line.isEmpty {
                line = abbr
            } else {
                line += ", \(abbr)"
            }
        }

        // ZIP (first 5 digits only)
        if let zip = currentLocation.zipcode, !zip.isEmpty {
            let digits = zip.split(separator: "-").first.map(String.init) ?? zip
            let short = String(digits.filter(\.isNumber).prefix(5))
            if !short.isEmpty {
                line += line.isEmpty ? short : " \(short)"
            }
        }

        return line.isEmpty ? nil : line
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
