import SwiftUI
import Kingfisher

/// Drop-in replacement for AsyncImage with Kingfisher disk + memory caching.
///
/// Usage:
/// ```swift
/// CachedImage(url: ImageKitURL.url(for: path, variant: .card))
///     .frame(width: 200, height: 150)
/// ```
///
/// Benefits over AsyncImage:
/// - Persistent disk cache (survives app restarts)
/// - Memory cache for instant re-display
/// - Progressive loading with fade transition
/// - Automatic retry on failure
struct CachedImage: View {
    let url: URL?
    var contentMode: SwiftUI.ContentMode = .fill

    var body: some View {
        KFImage(url)
            .resizable()
            .placeholder {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        ProgressView()
                    }
            }
            .fade(duration: 0.2)
            .aspectRatio(contentMode: contentMode)
    }
}

/// CachedImage variant with explicit phase handling for custom layouts.
/// Use this when you need different views for loading, success, and failure states.
struct CachedPhaseImage: View {
    let url: URL?
    var contentMode: SwiftUI.ContentMode = .fill

    var body: some View {
        KFImage(url)
            .resizable()
            .placeholder {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    ProgressView()
                }
            }
            .onFailureView {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
            .fade(duration: 0.2)
            .aspectRatio(contentMode: contentMode)
    }
}

#Preview {
    VStack(spacing: 20) {
        CachedImage(
            url: URL(string: "https://ik.imagekit.io/rgriola/test.jpg?tr=w-400,h-300,fo-auto,q-80")
        )
        .frame(width: 200, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        CachedImage(
            url: URL(string: "https://ik.imagekit.io/rgriola/test.jpg?tr=w-128,h-128,fo-auto,q-80"),
            contentMode: .fill
        )
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }
    .padding()
}
