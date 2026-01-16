import SwiftUI

/// Detail view for a single location
struct LocationDetailView: View {
    let location: Location
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(location.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(location.address ?? "No address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: typeIcon(for: location.type ?? ""))
                            .font(.caption)
                        Text(location.type ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(typeColor(for: location.type ?? "").opacity(0.2))
                    .foregroundColor(typeColor(for: location.type ?? ""))
                    .clipShape(Capsule())
                }
                .padding()
                
                Divider()
                
                // Location details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                    
                    DetailRow(label: "Latitude", value: String(format: "%.6f", location.latitude))
                    DetailRow(label: "Longitude", value: String(format: "%.6f", location.longitude))
                    DetailRow(label: "Place ID", value: location.placeId)
                    DetailRow(label: "Created", value: formatDate(location.createdAt))
                    
                    if let count = location.photosCount {
                        DetailRow(label: "Photos", value: "\(count)")
                    }
                }
                .padding()
                
                Divider()
                
                // Photos section (placeholder)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photos")
                        .font(.headline)
                    
                    if let count = location.photosCount, count > 0 {
                        Text("Photo gallery coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No photos yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper Functions
    
    private func typeIcon(for type: String) -> String {
        switch type.uppercased() {
        case "BROLL": return "video.fill"
        case "STORY": return "book.fill"
        case "INTERVIEW": return "mic.fill"
        case "ESTABLISHING": return "building.2.fill"
        case "DETAIL": return "magnifyingglass"
        case "WIDE": return "arrow.up.left.and.arrow.down.right"
        case "MEDIUM": return "rectangle.fill"
        case "CLOSE": return "circle.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func typeColor(for type: String) -> Color {
        switch type.uppercased() {
        case "BROLL": return .blue
        case "STORY": return .purple
        case "INTERVIEW": return .orange
        case "ESTABLISHING": return .green
        case "DETAIL": return .pink
        case "WIDE": return .cyan
        case "MEDIUM": return .indigo
        case "CLOSE": return .red
        default: return .gray
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LocationDetailView(location: Location(
            id: 1,
            name: "Dining Room",
            address: "123 Main St, New York, NY",
            latitude: 40.7128,
            longitude: -74.0060,
            type: "BROLL",
            placeId: "photo-123456",
            createdAt: Date().ISO8601Format(),
            photosCount: 3,
            thumbnailUrl: nil
        ))
    }
}
