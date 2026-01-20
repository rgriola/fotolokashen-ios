import SwiftUI

/// Individual location row component for the location list
struct LocationRow: View {
    let location: Location
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: location.thumbnailUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo.fill")
                                .foregroundColor(.gray)
                        }
                @unknown default:
                    EmptyView()
                }
            }
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
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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
