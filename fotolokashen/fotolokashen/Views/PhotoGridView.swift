import SwiftUI

/// A horizontal scroll strip of photo thumbnails with an add button.
/// Replaces the 3-column grid — keeps photos compact so the form is visible
/// without scrolling, especially when the panel is a sheet over the camera.
struct PhotoGridView: View {
    let photos: [PipelinePhoto]
    let maxPhotos: Int
    let onAddTapped: () -> Void
    let onRemovePhoto: (UUID) -> Void

    /// Thumbnail size — square, fixed, fits ~4 on a standard screen width
    private let thumbSize: CGFloat = 80

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Existing photos
                ForEach(photos) { photo in
                    photoThumb(photo)
                }

                // Add more button (if under limit)
                if photos.count < maxPhotos {
                    addButton
                }
            }
            .padding(.horizontal, 1) // prevents clipping of corner shadows
        }
    }

    // MARK: - Photo Thumbnail

    @ViewBuilder
    private func photoThumb(_ photo: PipelinePhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.originalImage)
                .resizable()
                .scaledToFill()
                .frame(width: thumbSize, height: thumbSize)
                .clipped()
                .cornerRadius(10)

            // Remove (×) button — top-right corner
            Button {
                onRemovePhoto(photo.id)
            } label: {
                Image(systemName: AppIcons.close)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.destructive)
                    .clipShape(Circle())
            }
            .offset(x: 6, y: -6)

            // Source badge — bottom-left  
            VStack {
                Spacer()
                HStack {
                    sourceBadge(photo.source)
                    Spacer()
                }
            }
            .padding(4)
        }
        .frame(width: thumbSize, height: thumbSize)
    }

    // MARK: - Source Badge

    @ViewBuilder
    private func sourceBadge(_ source: PhotoSource) -> some View {
        let icon = source == .camera ? AppIcons.camera : "photo.on.rectangle"
        Image(systemName: icon)
            .font(.system(size: 9))
            .foregroundColor(.white)
            .padding(3)
            .background(Color.black.opacity(0.55))
            .cornerRadius(4)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: onAddTapped) {
            VStack(spacing: 4) {
                Image(systemName: AppIcons.add)
                    .font(.title3)
                    .foregroundColor(.brand)
                Text("\(photos.count)/\(maxPhotos)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: thumbSize, height: thumbSize)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [5])
                    )
                    .foregroundColor(Color(.separator))
            )
        }
    }
}
