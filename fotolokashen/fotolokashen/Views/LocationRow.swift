import SwiftUI

/// Individual location row component for the location list
struct LocationRow: View {
    let location: Location

    /// Whether to show the share button (hidden inside swipe actions or other contexts)
    var showShareButton: Bool = true

    private var staticMapURL: URL? {
        let key = ConfigLoader.shared.googleMapsAPIKey
        guard !key.isEmpty else { return nil }
        let urlString = "https://maps.googleapis.com/maps/api/staticmap"
            + "?center=\(location.lat),\(location.lng)"
            + "&zoom=15&size=160x160&scale=2"
            + "&markers=color:red%7C\(location.lat),\(location.lng)"
            + "&key=\(key)"
        return URL(string: urlString)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail — photo if available, otherwise static map
            locationThumbnail
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Location info
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(location.name)
                    .font(.headline)
                    .lineLimit(1)

                // Address
                Text(location.address ?? "No address")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Type badge and photo count
                HStack(spacing: 8) {
                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: typeIcon(for: location.type ?? ""))
                            .font(.caption)
                        Text(location.type ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(typeColor(for: location.type ?? "").opacity(0.2))
                    .foregroundColor(typeColor(for: location.type ?? ""))
                    .clipShape(Capsule())

                    // Photo count
                    if let count = location.photosCount, count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.fill")
                                .font(.caption)
                            Text("\(count)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Share button
            if showShareButton {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var locationThumbnail: some View {
        if let thumbnailUrl = location.thumbnailUrl, let url = URL(string: thumbnailUrl) {
            // Photo thumbnail
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                case .failure:
                    staticMapThumbnail
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay { ProgressView() }
                }
            }
        } else {
            // No photo — show static map
            staticMapThumbnail
        }
    }

    @ViewBuilder
    private var staticMapThumbnail: some View {
        if let mapURL = staticMapURL {
            AsyncImage(url: mapURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                case .failure:
                    mapPlaceholder
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay { ProgressView() }
                }
            }
        } else {
            mapPlaceholder
        }
    }

    private var mapPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "map")
                    .foregroundColor(.gray)
            }
    }

    // MARK: - Share

    private var shareText: String {
        var text = location.name
        if let address = location.address {
            text += "\n\(address)"
        }
        text += "\nhttps://www.google.com/maps/search/?api=1&query=\(location.lat),\(location.lng)"
        return text
    }

    // MARK: - Helper Functions

    private func typeIcon(for type: String) -> String {
        return LocationTypeColors.icon(for: type)
    }

    private func typeColor(for type: String) -> Color {
        return LocationTypeColors.color(for: type)
    }
}

// MARK: - Preview

#Preview {
    List {
        LocationRow(location: Location(
            id: 1,
            name: "Dining Room",
            address: "123 Main St, New York, NY",
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
            address: "456 Park Ave, Brooklyn, NY",
            latitude: 40.6782,
            longitude: -73.9442,
            type: "STORY",
            placeId: "test",
            createdAt: Date().ISO8601Format(),
            photosCount: 1,
            thumbnailUrl: nil
        ))
    }
}
