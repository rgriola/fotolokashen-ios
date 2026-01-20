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
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Photo Gallery Section (Top)
                photoGallerySection
                
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Address Section
                    addressSection
                    
                    Divider()
                    
                    // MARK: - Type & Basic Info
                    typeSection
                    
                    Divider()
                    
                    // MARK: - Location Data (from locations table)
                    locationDataSection
                    
                    Divider()
                    
                    // MARK: - User Save Data (from user_saves table)
                    userSaveDataSection
                    
                    Divider()
                    
                    // MARK: - Photo Metadata (from photos table)
                    photoMetadataSection
                    
                    Divider()
                    
                    // MARK: - Coordinates & Map Data
                    coordinatesSection
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(location.name)
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
            googleMapsStaticImage
        } else {
            // Offline - show placeholder
            offlinePlaceholder
        }
    }
    
    // MARK: - Google Maps Static Image
    
    private var googleMapsStaticImage: some View {
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        let mapUrl = "https://maps.googleapis.com/maps/api/staticmap?center=\(location.latitude),\(location.longitude)&zoom=16&size=600x300&maptype=roadmap&markers=color:red%7C\(location.latitude),\(location.longitude)&key=\(apiKey)"
        
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
    
    // MARK: - Address Section
    
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let address = location.address {
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
                Image(systemName: typeIcon(for: location.type ?? ""))
                    .font(.subheadline)
                Text(location.type ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(typeColor(for: location.type ?? "").opacity(0.2))
            .foregroundColor(typeColor(for: location.type ?? ""))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Location Data Section (locations table)
    
    private var locationDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Location Data", icon: "mappin.and.ellipse")
            
            DetailRow(label: "Location ID", value: "\(location.id)")
            DetailRow(label: "Place ID", value: location.placeId)
            DetailRow(label: "Name", value: location.name)
            DetailRow(label: "Address", value: location.address ?? "N/A")
            DetailRow(label: "Latitude", value: String(format: "%.6f", location.latitude))
            DetailRow(label: "Longitude", value: String(format: "%.6f", location.longitude))
            DetailRow(label: "Type", value: location.type ?? "N/A")
            DetailRow(label: "Notes", value: location.notes ?? "N/A")
            
            if let rating = location.rating {
                DetailRow(label: "Rating", value: String(format: "%.1f", rating))
            } else {
                DetailRow(label: "Rating", value: "N/A")
            }
            
            DetailRow(label: "Created At", value: formatDate(location.createdAt))
            DetailRow(label: "Photos Count", value: "\(location.photosCount ?? 0)")
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
                DetailRow(label: "UserSave ID", value: "\(location.userSaveId ?? 0)")
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
            
            DetailRow(label: "Latitude", value: String(format: "%.8f", location.latitude))
            DetailRow(label: "Longitude", value: String(format: "%.8f", location.longitude))
            DetailRow(label: "Coordinate String", value: "\(location.latitude), \(location.longitude)")
            
            // Copy coordinates button
            Button {
                UIPasteboard.general.string = "\(location.latitude), \(location.longitude)"
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
    
    // MARK: - Data Loading
    
    private func loadPhotos() async {
        guard let userSaveId = location.userSaveId else {
            isLoadingPhotos = false
            return
        }
        
        do {
            let response: PhotosResponse = try await APIClient.shared.get("/api/locations/\(userSaveId)/photos")
            await MainActor.run {
                self.photos = response.photos
                self.isLoadingPhotos = false
            }
        } catch {
            print("[LocationDetailView] Failed to load photos: \(error)")
            await MainActor.run {
                // Use embedded photos as fallback
                self.photos = (location.photos ?? []).map { photo in
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
        guard let userSaveId = location.userSaveId else {
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
        switch type.lowercased() {
        case "outdoor": return "sun.max"
        case "indoor": return "house"
        case "studio": return "camera.fill"
        case "urban": return "building.2"
        case "nature": return "leaf"
        case "architectural": return "building.columns"
        default: return "mappin.circle.fill"
        }
    }
    
    private func typeColor(for type: String) -> Color {
        switch type.lowercased() {
        case "outdoor": return .orange
        case "indoor": return .blue
        case "studio": return .purple
        case "urban": return .gray
        case "nature": return .green
        case "architectural": return .brown
        default: return .gray
        }
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
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
        }
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
            type: "outdoor",
            placeId: "place-123",
            createdAt: "2026-01-20T10:00:00Z",
            photosCount: 3,
            thumbnailUrl: nil,
            userSaveId: 1
        ))
        .environmentObject(NetworkMonitor.shared)
    }
}
