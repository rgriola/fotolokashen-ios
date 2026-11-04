import Kingfisher
import SwiftUI
import UIKit

// MARK: - Photo Gallery Section

/// Swipeable photo gallery with loading, fallback, and full-screen support.
/// Extracted from LocationDetailView for file-length compliance.
struct PhotoGallerySection: View {
    @Binding var photos: [DetailPhoto]
    @Binding var isLoading: Bool
    let locationType: String?
    let latitude: Double
    let longitude: Double
    let isConnected: Bool
    @Binding var selectedPhotoIndex: Int
    @Binding var showingFullScreenGallery: Bool
    let currentPhotoRevision: () -> UInt64
    var imageSource: (DetailPhoto) -> Source? = { photo in
        URL(string: photo.url).map { .network($0) }
    }
    @State private var photoGeneration = 0

    private var photoSnapshot: PhotoGallerySnapshot {
        let currentPhotos = $photos
        let currentLoading = $isLoading
        let currentPresentation = $showingFullScreenGallery
        return PhotoGallerySnapshot(
            photoIDs: photos.map(\.id),
            generation: $photoGeneration,
            currentPhotoIDs: { currentPhotos.wrappedValue.map(\.id) },
            currentPhotoRevision: currentPhotoRevision,
            isAvailable: { !currentLoading.wrappedValue && !currentPresentation.wrappedValue }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            galleryContent

            // Type badge (category like BROLL, STORY, etc.)
            if let type = locationType, !type.isEmpty {
                typeBadge(type: type)
                    .padding(12)
            }
        }
        .onChange(of: PhotoGallerySourceVersion(
            photoIDs: photos.map(\.id), revision: currentPhotoRevision()
        ), initial: true) { _, _ in
            photoGeneration += 1
            PhotoGallerySelection.reconcile($selectedPhotoIndex, count: $photos.wrappedValue.count)
        }
        .onChange(of: isLoading) { _, _ in photoGeneration += 1 }
        .onDisappear { photoGeneration += 1 }
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
            let snapshot = photoSnapshot
            let selection = PhotoGallerySelection.clampedBinding($selectedPhotoIndex, snapshot: snapshot)
            VStack(spacing: 0) {
                TabView(selection: selection) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        KFImage(source: imageSource(photo))
                            .resizable()
                            .placeholder {
                                ZStack {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                    ProgressView()
                                }
                            }
                            .onFailureView {
                                Image(systemName: AppIcons.photo)
                                    .foregroundStyle(Color.secondary)
                            }
                            .fade(duration: 0.2)
                            .scaledToFill()
                            .onTapGesture {
                                PhotoGallerySelection.openPhoto(
                                    at: index,
                                    snapshot: snapshot,
                                    selection: $selectedPhotoIndex,
                                    isPresented: $showingFullScreenGallery
                                )
                            }
                            .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
                            .accessibilityHint("Opens the full-screen photo gallery")
                            .accessibilityAddTraits(.isButton)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .onAppear { reconcileLiveSelection() }
                .frame(height: 300)
                .clipped()

                // Photo counter badge
                HStack {
                    Spacer()
                    Text("\(selection.wrappedValue + 1) / \(photos.count)")
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
        } else {
            Group {
                if isConnected {
                    googleMapsStaticImageSection
                } else {
                    offlinePlaceholder
                }
            }
            .onAppear { reconcileLiveSelection() }
        }
    }

    private func reconcileLiveSelection() {
        guard !$isLoading.wrappedValue, !$showingFullScreenGallery.wrappedValue else { return }
        PhotoGallerySelection.reconcile($selectedPhotoIndex, count: $photos.wrappedValue.count)
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
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LocationTypeColors.color(for: type))
        .clipShape(Capsule())
    }

    // MARK: - Static Map Fallback

    private var googleMapsStaticImageSection: some View {
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        let mapUrl = "https://maps.googleapis.com/maps/api/staticmap?center=\(latitude),\(longitude)&zoom=16&size=600x300&maptype=roadmap&markers=color:red%7C\(latitude),\(longitude)&key=\(apiKey)"

        return KFImage(URL(string: mapUrl))
            .resizable()
            .placeholder {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 200)
                    ProgressView()
                }
            }
            .onFailureView { offlinePlaceholder }
            .fade(duration: 0.2)
            .scaledToFill()
            .frame(height: 200)
            .clipped()
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: AppIcons.noPhoto)
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
    }

    // MARK: - Offline Placeholder

    private var offlinePlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 200)

            VStack(spacing: 12) {
                Image(systemName: AppIcons.offline)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.secondary)

                Text("No connection")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)

                Text("Photos will load when online")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

// MARK: - Full Screen Photo Gallery

struct PhotoGalleryFullScreen: View {
    @Binding var photos: [DetailPhoto]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    let currentPhotoRevision: () -> UInt64
    var imageSource: (DetailPhoto) -> Source? = { photo in
        ImageKitURL.url(for: photo.imagekitFilePath, variant: .full).map { .network($0) }
    }
    @State private var accessibilityState = PhotoGalleryAccessibilityState()
    @State private var photoGeneration = 0

    private var photoSnapshot: PhotoGallerySnapshot {
        let currentPhotos = $photos
        let currentPresentation = $isPresented
        return PhotoGallerySnapshot(
            photoIDs: photos.map(\.id),
            generation: $photoGeneration,
            currentPhotoIDs: { currentPhotos.wrappedValue.map(\.id) },
            currentPhotoRevision: currentPhotoRevision,
            isAvailable: { currentPresentation.wrappedValue }
        )
    }

    var body: some View {
        let snapshot = photoSnapshot
        let selection = PhotoGallerySelection.clampedBinding($selectedIndex, snapshot: snapshot)
        ZStack {
            Color.black.ignoresSafeArea()

            if photos.isEmpty {
                ContentUnavailableView("No Photos", systemImage: AppIcons.photo)
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)
                    .onAppear {
                        reconcileLiveState()
                    }
            } else {
                TabView(selection: selection) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        // Full-screen uses the full variant URL for highest quality
                        KFImage(source: imageSource(photo))
                            .resizable()
                            .placeholder {
                                ProgressView()
                                    .tint(.white)
                            }
                            .onFailureView {
                                Image(systemName: AppIcons.photo)
                                    .foregroundStyle(Color.secondary)
                            }
                            .fade(duration: 0.2)
                            .scaledToFit()
                            .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .onAppear { reconcileLiveState() }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        PhotoGallerySelection.closeGallery(
                            generation: $photoGeneration,
                            isPresented: $isPresented
                        )
                    } label: {
                        Image(systemName: AppIcons.closeCircle)
                            .font(.title)
                            .foregroundStyle(Color.white)
                            .padding()
                    }
                    .accessibilityLabel("Close photo gallery")
                }
                Spacer()

                // Photo info
                if !photos.isEmpty {
                    let photo = photos[selection.wrappedValue]
                    VStack(spacing: 4) {
                        Text("\(selection.wrappedValue + 1) of \(photos.count)")
                            .font(.headline)
                            .foregroundStyle(Color.white)

                        if let caption = photo.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: PhotoGallerySourceVersion(
            photoIDs: photos.map(\.id), revision: currentPhotoRevision()
        ), initial: true) { _, _ in
            guard $isPresented.wrappedValue else { return }
            photoGeneration += 1
            reconcileLiveState()
        }
        .onDisappear {
            guard $isPresented.wrappedValue else { return }
            photoGeneration += 1
        }
    }

    private func reconcileLiveState() {
        guard $isPresented.wrappedValue else { return }
        let photoIDs = $photos.wrappedValue.map(\.id)
        let revision = currentPhotoRevision()
        PhotoGallerySelection.reconcile($selectedIndex, count: photoIDs.count)
        guard $isPresented.wrappedValue, currentPhotoRevision() == revision,
              $photos.wrappedValue.map(\.id) == photoIDs else { return }
        if let announcement = accessibilityState.observe(
            isEmpty: photoIDs.isEmpty,
            photoIDs: photoIDs,
            isPresented: true
        ) {
            announce(announcement)
        }
    }

    private func announce(_ announcement: PhotoGalleryAvailabilityAnnouncement) {
        let message = switch announcement {
        case .photosAvailable: String(localized: "Photos available.")
        case .noPhotos: String(localized: "No photos available.")
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Photo Types

/// Response from /api/locations/{id}/photos
nonisolated struct PhotosResponse: Codable {
    let photos: [DetailPhoto]
    let pagination: PhotoPagination?
}

nonisolated struct PhotoPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

/// Detailed photo information from API
nonisolated struct DetailPhoto: Codable, Identifiable {
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
                url: ImageKitURL.url(for: photo.imagekitFilePath, variant: .gallery)?.absoluteString
                    ?? "\(ImageKitURL.baseURL)\(photo.imagekitFilePath)",
                thumbnailUrl: ImageKitURL.url(for: photo.imagekitFilePath, variant: .thumbnail)?.absoluteString
                    ?? "\(ImageKitURL.baseURL)\(photo.imagekitFilePath)",
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
                .foregroundStyle(Color.brand)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the fixed label column forces mid-word
        // hyphenation, so the label stacks above the value instead.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                Text(value)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 120, alignment: .leading)
                Text(value)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
