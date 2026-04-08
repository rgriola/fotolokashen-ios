import SwiftUI

// MARK: - Photo Gallery Section

/// Swipeable photo gallery with loading, fallback, and full-screen support.
/// Extracted from LocationDetailView for file-length compliance.
struct PhotoGallerySection: View {
    let photos: [DetailPhoto]
    let isLoading: Bool
    let locationType: String?
    let latitude: Double
    let longitude: Double
    let isConnected: Bool
    @Binding var selectedPhotoIndex: Int
    @Binding var showingFullScreenGallery: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            galleryContent

            // Type badge (category like BROLL, STORY, etc.)
            if let type = locationType, !type.isEmpty {
                typeBadge(type: type)
                    .padding(12)
            }
        }
    }

    // MARK: - Gallery Content

    @ViewBuilder
    private var galleryContent: some View {
        if isLoading {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                ProgressView()
                    .scaleEffect(1.5)
            }
        } else if !photos.isEmpty {
            VStack(spacing: 0) {
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
                                        .foregroundColor(Color(.tertiaryLabel))
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
            }
        } else if isConnected {
            googleMapsStaticImageSection
        } else {
            offlinePlaceholder
        }
    }

    // MARK: - Type Badge

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

    // MARK: - Static Map Fallback

    private var googleMapsStaticImageSection: some View {
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        let mapUrl = "https://maps.googleapis.com/maps/api/staticmap?center=\(latitude),\(longitude)&zoom=16&size=600x300&maptype=roadmap&markers=color:red%7C\(latitude),\(longitude)&key=\(apiKey)"

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
                    .foregroundColor(.secondary)

                Text("No connection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Photos will load when online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

// MARK: - Photo Types

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

    /// Convert LocationPhoto array to DetailPhoto array (ImageKit URL construction)
    static func fromLocationPhotos(_ photos: [LocationPhoto]) -> [DetailPhoto] {
        photos.map { photo in
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
    }
}

// MARK: - Reusable Detail Components

/// Section header with icon
struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.brand)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.top, 4)
    }
}

/// Label-value row for detail display
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
