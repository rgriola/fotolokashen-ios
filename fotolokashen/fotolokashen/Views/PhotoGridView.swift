import SwiftUI

/// A 3-column photo grid that displays pipeline photos with add/remove controls.
/// Shows an "Add" button at the end when under the photo limit.
///
/// Reusable across apps — depends only on PipelinePhoto and AppColors/AppIcons conventions.
struct PhotoGridView: View {
    let photos: [PipelinePhoto]
    let maxPhotos: Int
    let onAddTapped: () -> Void
    let onRemovePhoto: (UUID) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            // Existing photos
            ForEach(photos) { photo in
                photoCell(photo)
            }

            // Add button (if under limit)
            if photos.count < maxPhotos {
                addButton
            }
        }
    }

    // MARK: - Photo Cell

    @ViewBuilder
    private func photoCell(_ photo: PipelinePhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.originalImage)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(8)

            // Remove button
            Button {
                onRemovePhoto(photo.id)
            } label: {
                Image(systemName: AppIcons.close)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.destructive.opacity(0.8))
                    .clipShape(Circle())
            }
            .padding(4)

            // Source badge (camera or library icon)
            VStack {
                Spacer()
                HStack {
                    sourceBadge(photo.source)
                    Spacer()
                }
            }
            .padding(4)
        }
    }

    // MARK: - Source Badge

    @ViewBuilder
    private func sourceBadge(_ source: PhotoSource) -> some View {
        let icon = source == .camera ? AppIcons.camera : "photo.on.rectangle"
        Image(systemName: icon)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(3)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: onAddTapped) {
            VStack(spacing: 6) {
                Image(systemName: AppIcons.add)
                    .font(.title2)
                    .foregroundColor(.brand)
                Text("\(photos.count)/\(maxPhotos)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
                    .foregroundColor(Color(.separator))
            )
        }
    }
}
