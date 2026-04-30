import SwiftUI

/// A horizontal scroll strip of photo thumbnails with an add button.
/// Replaces the 3-column grid — keeps photos compact so the form is visible
/// without scrolling, especially when the panel is a sheet over the camera.
struct PhotoGridView: View {
    let photos: [PipelinePhoto]
    let maxPhotos: Int
    let onAddTapped: () -> Void
    let onRemovePhoto: (UUID) -> Void
    /// Optional: invoked when the user taps the retry button on a failed photo.
    /// Only shown when `photo.stage == .failed(_, retryable: true)`.
    var onRetryPhoto: ((UUID) -> Void)? = nil

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

            // Stage overlay (compressing spinner / upload progress / failure /
            // success). Renders nothing for `.picked` and `.compressed` so the
            // legacy flow (where stage stays `.picked`) is visually unchanged.
            stageOverlay(for: photo)

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

    // MARK: - Stage Overlay

    @ViewBuilder
    private func stageOverlay(for photo: PipelinePhoto) -> some View {
        switch photo.stage {
        case .picked, .compressed:
            EmptyView()

        case .compressing:
            ZStack {
                Color.black.opacity(0.35)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(0.8)
            }
            .frame(width: thumbSize, height: thumbSize)
            .cornerRadius(10)

        case .queuedForUpload:
            ZStack {
                Color.black.opacity(0.35)
                Image(systemName: "clock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .frame(width: thumbSize, height: thumbSize)
            .cornerRadius(10)

        case .uploading(let progress):
            ZStack {
                Color.black.opacity(0.35)
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0, to: max(0.02, min(progress, 1.0)))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.15), value: progress)
            }
            .frame(width: thumbSize, height: thumbSize)
            .cornerRadius(10)

        case .uploaded:
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.success)
                        .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                        .padding(4)
                }
                Spacer()
            }
            .frame(width: thumbSize, height: thumbSize)

        case .failed(_, let retryable):
            ZStack {
                Color.destructive.opacity(0.55)
                if retryable, let onRetry = onRetryPhoto {
                    Button {
                        onRetry(photo.id)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .frame(width: thumbSize, height: thumbSize)
            .cornerRadius(10)
        }
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
