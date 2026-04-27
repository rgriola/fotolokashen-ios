import SwiftUI

/// Accordion header for a LocationGroup in the location list.
/// Displays group name, type icon, location count badge, and expand/collapse chevron.
struct GroupAccordionHeader: View {
    let group: LocationGroup
    let locationCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Type icon
                Image(systemName: iconForType(group.type))
                    .font(.subheadline)
                    .foregroundStyle(colorForType(group.type))
                    .frame(width: 24, height: 24)

                // Group name
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let type = group.type {
                        Text(type.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Location count badge
                Text("\(locationCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(colorForType(group.type).opacity(0.8))
                    .clipShape(Capsule())

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func iconForType(_ type: String?) -> String {
        guard let t = type?.uppercased() else { return "folder" }
        switch t {
        case "EVENT": return "calendar"
        case "ROUTE": return "map"
        case "STORY": return "book"
        case "COVERAGE": return "video"
        default: return "tag"
        }
    }

    private func colorForType(_ type: String?) -> Color {
        guard let t = type?.uppercased() else { return .gray }
        switch t {
        case "EVENT": return .orange
        case "ROUTE": return .blue
        case "STORY": return .purple
        case "COVERAGE": return .red
        default: return .teal
        }
    }
}
