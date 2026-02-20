import SwiftUI

/// Detail view for a single location with full metadata
struct LocationDetailView: View {
    let location: Location
    @State private var photos: [DetailPhoto] = []
    @State private var isLoadingPhotos = true
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingFullScreenGallery = false
    @State private var userSaveDetails: UserSaveWithLocation?
    @State private var isLoadingDetails = true
    @State private var showingEditView = false
    @State private var currentLocation: Location
    @State private var locationVisibility: String
    @State private var isSavingVisibility = false
    @EnvironmentObject var networkMonitor: NetworkMonitor

    init(location: Location) {
        self.location = location
        self._currentLocation = State(initialValue: location)
        self._locationVisibility = State(initialValue: location.visibility ?? "private")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Photo Gallery
                photoGallerySection

                // Top Bar: type badge with visibility icon (left) + menu (right)
                HStack(alignment: .center) {
                    if let type = currentLocation.type, !type.isEmpty {
                        HStack(spacing: 3) {
                            Text(type)
                            Image(systemName: visibilityIcon(for: currentLocation.visibility ?? "private"))
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(typeColor(for: type))
                        .clipShape(Capsule())
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Button(action: { showingEditView = true }) {
                            Image(systemName: "square.and.pencil")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(4)
                        }
                        if let username = currentLocation.creator?.username,
                           let url = URL(string: "https://fotolokashen.com/\(username)/locations/\(currentLocation.id)") {
                            ShareLink(
                                item: url,
                                subject: Text(currentLocation.name),
                                message: Text(currentLocation.address ?? "")
                            ) {
                                Image(systemName: "arrowshape.turn.up.right")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .padding(4)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 20) {
                    // --- Always Show Section ---
                    Group {
                        Text(currentLocation.name)
                            .font(.title2).fontWeight(.bold)
                        if let address = currentLocation.address, !address.isEmpty {
                            Button(action: {
                                LocationStore.shared.mapFocusLocation = currentLocation
                                NotificationCenter.default.post(name: .navigateToMapTab, object: nil)
                            }) {
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "mappin.circle.fill").foregroundColor(.red)
                                    Text(address)
                                        .font(.body)
                                        .foregroundColor(.blue)
                                        .underline()
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Text("Added \(formatDate(currentLocation.createdAt))")
                            .font(.footnote).foregroundColor(.secondary)
                        if let creator = userSaveDetails?.location.creator?.username {
                            Text("by @\(creator)")
                                .font(.footnote).foregroundColor(.secondary)
                        }

                        // --- Visibility Control ---
                        visibilityControlRow
                    }

                    Divider()

                    // --- Location Details (Conditional) ---
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

                    // --- Location Extra Metadata (Conditional) ---
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

                    // --- Support Info at Bottom ---
                    Spacer(minLength: 32)
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
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(currentLocation.name)
        .sheet(isPresented: $showingEditView) {
            EditLocationView(location: currentLocation) { updated in
                currentLocation = updated
                Task {
                    await loadPhotos()
                    await loadUserSaveDetails()
                }
            }
        }
        .task {
            await loadPhotos()
            await loadUserSaveDetails()
        }
        .fullScreenCover(isPresented: $showingFullScreenGallery) {
            PhotoGalleryFullScreen(
                photos: photos,
                selectedIndex: $selectedPhotoIndex
            )
        }
    }
    
    // MARK: - Photo Gallery Section
    
    @ViewBuilder
    private var photoGallerySection: some View {
        if isLoadingPhotos {
            // Loading state
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                ProgressView()
                    .scaleEffect(1.5)
            }
        } else if !photos.isEmpty {
            // Photo gallery
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
            
            // Photo counter
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
    
    // MARK: - Google Maps Static Image
    
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
    
    // MARK: - Offline Placeholder
    
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
    
    // MARK: - Visibility Control

    private var visibilityControlRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: visibilityIcon(for: locationVisibility))
                    .foregroundColor(visibilityColor(for: locationVisibility))
                    .frame(width: 20)

                Text("Visibility")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

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
            }

            Text(visibilityDescription(for: locationVisibility))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 28)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Address Section
    
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentLocation.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let address = currentLocation.address {
                HStack(alignment: .top) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text(address)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Type Section
    
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type")
                .font(.headline)
            
            HStack(spacing: 4) {
                Image(systemName: typeIcon(for: currentLocation.type ?? ""))
                    .font(.subheadline)
                Text(currentLocation.type ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(typeColor(for: currentLocation.type ?? "").opacity(0.2))
            .foregroundColor(typeColor(for: currentLocation.type ?? ""))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Location Data Section (locations table)
    
    private var locationDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Location Data", icon: "mappin.and.ellipse")
            
            DetailRow(label: "Location ID", value: "\(currentLocation.id)")
            DetailRow(label: "Place ID", value: currentLocation.placeId)
            DetailRow(label: "Name", value: currentLocation.name)
            DetailRow(label: "Address", value: currentLocation.address ?? "N/A")
            DetailRow(label: "Latitude", value: String(format: "%.6f", currentLocation.latitude))
            DetailRow(label: "Longitude", value: String(format: "%.6f", currentLocation.longitude))
            DetailRow(label: "Type", value: currentLocation.type ?? "N/A")
            DetailRow(label: "Notes", value: currentLocation.notes ?? "N/A")
            
            if let rating = currentLocation.rating {
                DetailRow(label: "Rating", value: String(format: "%.1f", rating))
            } else {
                DetailRow(label: "Rating", value: "N/A")
            }
            
            // Production Date
            if let productionDate = currentLocation.productionDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Production Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatProductionDate(productionDate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            DetailRow(label: "Created At", value: formatDate(currentLocation.createdAt))
            DetailRow(label: "Photos Count", value: "\(currentLocation.photosCount ?? 0)")
        }
    }
    
    // MARK: - User Save Data Section (user_saves table)
    
    private var userSaveDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "User Save Data", icon: "bookmark.fill")
            
            if isLoadingDetails {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let userSave = userSaveDetails {
                DetailRow(label: "UserSave ID", value: "\(userSave.id)")
                DetailRow(label: "User ID", value: "\(userSave.userId)")
                DetailRow(label: "Location ID", value: "\(userSave.locationId)")
                DetailRow(label: "Saved At", value: formatDate(userSave.savedAt ?? "N/A"))
                DetailRow(label: "Color", value: userSave.color ?? "N/A")
                DetailRow(label: "Is Favorite", value: userSave.isFavorite == true ? "Yes" : "No")
                
                if let rating = userSave.personalRating {
                    DetailRow(label: "Personal Rating", value: String(format: "%.1f", rating))
                } else {
                    DetailRow(label: "Personal Rating", value: "N/A")
                }
                
                DetailRow(label: "Caption", value: userSave.caption ?? "N/A")
            } else {
                DetailRow(label: "UserSave ID", value: "\(currentLocation.userSaveId ?? 0)")
                Text("Could not load user save details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Photo Metadata Section (photos table)
    
    private var photoMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Photo Data", icon: "photo.stack")
            
            if photos.isEmpty {
                Text("No photos available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        DetailRow(label: "Photo ID", value: "\(photo.id)")
                        DetailRow(label: "File Path", value: photo.imagekitFilePath)
                        DetailRow(label: "Caption", value: photo.caption ?? "N/A")
                        
                        if let width = photo.width, let height = photo.height {
                            DetailRow(label: "Dimensions", value: "\(width) x \(height)")
                        }
                        
                        DetailRow(label: "Uploaded At", value: formatDate(photo.uploadedAt ?? "N/A"))
                        
                        if let lat = photo.gpsLatitude, let lng = photo.gpsLongitude {
                            DetailRow(label: "GPS Lat", value: String(format: "%.6f", lat))
                            DetailRow(label: "GPS Lng", value: String(format: "%.6f", lng))
                        }
                        
                        DetailRow(label: "Is Primary", value: photo.isPrimary == true ? "Yes" : "No")
                        
                        if let fileSize = photo.fileSize {
                            DetailRow(label: "File Size", value: formatFileSize(fileSize))
                        }
                        
                        DetailRow(label: "MIME Type", value: photo.mimeType ?? "N/A")
                        
                        if index < photos.count - 1 {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Coordinates Section
    
    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Coordinates", icon: "location.circle")
            
            DetailRow(label: "Latitude", value: String(format: "%.8f", currentLocation.latitude))
            DetailRow(label: "Longitude", value: String(format: "%.8f", currentLocation.longitude))
            DetailRow(label: "Coordinate String", value: "\(currentLocation.latitude), \(currentLocation.longitude)")
            
            // Copy coordinates button
            Button {
                UIPasteboard.general.string = "\(currentLocation.latitude), \(currentLocation.longitude)"
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Coordinates")
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Visibility Helpers

    private func visibilityIcon(for v: String) -> String {
        switch v.lowercased() {
        case "public": return "globe"
        case "unlisted": return "person.2"
        default: return "lock"
        }
    }

    private func visibilityLabel(for v: String) -> String {
        switch v {
        case "public": return "Public"
        case "unlisted": return "Unlisted"
        default: return "Private"
        }
    }

    private func visibilityColor(for v: String) -> Color {
        switch v {
        case "public": return .green
        case "unlisted": return .orange
        default: return Color(.systemGray)
        }
    }

    private func visibilityDescription(for v: String) -> String {
        switch v {
        case "public": return "Anyone on fotolokashen can discover this location"
        case "unlisted": return "Only people with the direct link can view"
        default: return "Only you can see this location"
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

    // MARK: - Data Loading
    
    private func loadPhotos() async {
        // Use currentLocation.id (Location table ID), not userSaveId
        // The /api/locations/[id]/photos endpoint expects the Location ID
        let locationId = currentLocation.id
        
        do {
            let response: PhotosResponse = try await APIClient.shared.get("/api/locations/\(locationId)/photos")
            await MainActor.run {
                self.photos = response.photos
                self.isLoadingPhotos = false
            }
        } catch {
            print("[LocationDetailView] Failed to load photos: \(error)")
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
    
    private func loadUserSaveDetails() async {
        guard let userSaveId = currentLocation.userSaveId else {
            isLoadingDetails = false
            return
        }
        
        do {
            let response: UserSaveDetailResponse = try await APIClient.shared.get("/api/locations/\(userSaveId)")
            await MainActor.run {
                self.userSaveDetails = response.userSave
                self.isLoadingDetails = false
            }
        } catch {
            print("[LocationDetailView] Failed to load user save details: \(error)")
            await MainActor.run {
                self.isLoadingDetails = false
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func typeIcon(for type: String) -> String {
        return LocationTypeColors.icon(for: type)
    }
    
    private func typeColor(for type: String) -> Color {
        return LocationTypeColors.color(for: type)
    }
    
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
        formatter.dateStyle = .long  // "December 31, 2025"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)  // Force UTC to match backend
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
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

// MARK: - Photo Models

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

#Preview {
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
