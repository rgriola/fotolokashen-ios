import SwiftUI
import Kingfisher

/// Individual location card component matching the web app's photo-prominent design.
/// Vertical layout: photo carousel on top, name/address/badge below, three-dot menu.
struct LocationRow: View {
    let location: Location
    /// When true, shows a "Saved by @username" line for locations sourced from a friend/public feed.
    var showAttribution: Bool = false

    /// "Saved by @username" attribution text, only shown when `showAttribution` is true and a creator is known.
    private var attributionText: String? {
        guard showAttribution, let username = location.creator?.username, !username.isEmpty else { return nil }
        return "Saved by @\(username)"
    }

    // MARK: - Photo URLs

    /// All photo URLs from the location's photos array — optimized for card display
    private var photoURLs: [URL] {
        guard let photos = location.photos, !photos.isEmpty else { return [] }
        return photos.compactMap { $0.cardURL }
    }

    // MARK: - Static Map URL

    private var staticMapURL: URL? {
        let key = ConfigLoader.shared.googleMapsAPIKey
        guard !key.isEmpty else { return nil }
        let urlString = "https://maps.googleapis.com/maps/api/staticmap"
            + "?center=\(location.lat),\(location.lng)"
            + "&zoom=15&size=600x400&scale=2"
            + "&markers=color:red%7C\(location.lat),\(location.lng)"
            + "&key=\(key)"
        return URL(string: urlString)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo carousel area
            ZStack(alignment: .topLeading) {
                photoCarousel
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()

                // Overlays on photo
                HStack {
                    // Type badge with visibility icon (top-left)
                    if let type = location.type, !type.isEmpty {
                        HStack(spacing: 3) {
                            Text(type)
                            visibilityIcon(for: location.visibility)
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor(for: type))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Share button (top-right)
                    if let username = location.creator?.username,
                       let url = URL(string: "https://fotolokashen.com/\(username)/locations/\(location.id)") {
                        ShareLink(
                            item: url,
                            subject: Text(location.name),
                            message: Text(location.address ?? "")
                        ) {
                            Image(systemName: AppIcons.share)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.white)
                                .padding(8)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Share \(location.name)")
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }

            // Info area below photo
            VStack(alignment: .leading, spacing: 6) {
                // Name — full display, wraps to multiple lines
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Address — full display, wraps to multiple lines
                Text(location.address ?? "No address")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Favorite indicator
                if location.isFavorite == true {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.destructive)
                }

                // Attribution (friend/public locations)
                if let attributionText {
                    Text(attributionText)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
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
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle()) // Make entire card tappable for NavigationLink
    }

    // MARK: - Photo Carousel

    @ViewBuilder
    private var photoCarousel: some View {
        if photoURLs.count > 1 {
            // Multiple photos — swipeable carousel with tap-through for navigation
            TabView {
                ForEach(Array(photoURLs.enumerated()), id: \.offset) { _, url in
                    KFImage(url)
                        .resizable()
                        .placeholder {
                            Rectangle()
                                .fill(Color(.systemFill))
                                .overlay { ProgressView() }
                        }
                        .onFailureView {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.secondary)
                        }
                        .fade(duration: 0.2)
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipped()
                        .allowsHitTesting(false)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        } else if let firstURL = photoURLs.first {
            // Single photo
            KFImage(firstURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color(.systemFill))
                        .overlay { ProgressView() }
                }
                .onFailureView {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.secondary)
                }
                .fade(duration: 0.2)
                .aspectRatio(contentMode: .fill)
        } else {
            // No photos — static map fallback
            staticMapImage
        }
    }

    // MARK: - Static Map Fallback

    @ViewBuilder
    private var staticMapImage: some View {
        if let mapURL = staticMapURL {
            KFImage(mapURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color(.systemFill))
                        .overlay { ProgressView() }
                }
                .onFailureView { mapPlaceholder }
                .fade(duration: 0.2)
                .aspectRatio(contentMode: .fill)
        } else {
            mapPlaceholder
        }
    }

    private var photoErrorPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemFill))
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Color.secondary)
            }
    }

    private var mapPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemFill))
            .overlay {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(Color.secondary)
            }
    }


    // MARK: - Helpers

    private func typeColor(for type: String) -> Color {
        LocationTypeColors.color(for: type)
    }
    
    @ViewBuilder
    private func visibilityIcon(for visibility: String?) -> some View {
        switch visibility?.lowercased() {
        case "public":
            Image(systemName: "globe")
        case "unlisted":
            Image(systemName: "person.2")
        case "private":
            Image(systemName: "lock")
        default:
            Image(systemName: "lock") // Default to private
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            LocationRow(location: Location(
                id: 1,
                name: "Dining Room at the Grand Hotel",
                address: "123 Main St, New York, NY 10001",
                latitude: 40.7128,
                longitude: -74.0060,
                type: "BROLL",
                placeId: "test",
                createdAt: Date().ISO8601Format(),
                photosCount: 3,
                thumbnailUrl: nil
            ))

            LocationRow(location: Location(
                id: 2,
                name: "Coffee Shop Interior",
                address: "456 Park Ave, Brooklyn, NY 11215",
                latitude: 40.6782,
                longitude: -73.9442,
                type: "STORY",
                placeId: "test",
                createdAt: Date().ISO8601Format(),
                photosCount: 1,
                thumbnailUrl: nil
            ))
        }
        .padding()
    }
}
