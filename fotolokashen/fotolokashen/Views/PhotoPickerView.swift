import SwiftUI
import PhotosUI

/// A SwiftUI wrapper around PHPickerViewController for selecting photos from the user's library.
/// Supports multi-selection and returns raw Data (preserving EXIF) + UIImage pairs.
///
/// Reusable across apps — depends only on PhotoPipelineModels (PhotoSource, EXIFMetadata, PipelinePhoto).
struct PhotoPickerView: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onPhotosPicked: ([PipelinePhoto]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit
        config.filter = .images
        // Request current representation to preserve EXIF in original format
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhotosPicked: onPhotosPicked)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPhotosPicked: ([PipelinePhoto]) -> Void

        init(onPhotosPicked: @escaping ([PipelinePhoto]) -> Void) {
            self.onPhotosPicked = onPhotosPicked
        }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            // Empty selection — dismiss immediately
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                onPhotosPicked([])
                return
            }

            // Show full-screen blur loading overlay while photos load (A3)
            let loadingVC = makeLoadingOverlay(photoCount: results.count)
            picker.present(loadingVC, animated: true)

            Task {
                // Load all photos concurrently via TaskGroup (A1)
                let photos = await withTaskGroup(of: PipelinePhoto?.self, returning: [PipelinePhoto].self) { group in
                    for result in results {
                        group.addTask { [weak self] in
                            await self?.loadPhoto(from: result)
                        }
                    }
                    var collected: [PipelinePhoto] = []
                    for await photo in group {
                        if let photo { collected.append(photo) }
                    }
                    return collected
                }

                // Dismiss loading overlay, then picker, then deliver photos (A3)
                await MainActor.run {
                    loadingVC.dismiss(animated: false) {
                        picker.dismiss(animated: true)
                    }
                    onPhotosPicked(photos)
                }
            }
        }

        // MARK: - Loading Overlay (A3)

        /// Create a full-screen blurred loading overlay presented on top of the picker.
        private func makeLoadingOverlay(photoCount: Int) -> UIViewController {
            let hostingController = UIHostingController(rootView: PhotoLoadingOverlay(photoCount: photoCount))
            hostingController.modalPresentationStyle = .overFullScreen
            hostingController.modalTransitionStyle = .crossDissolve
            hostingController.view.backgroundColor = .clear
            return hostingController
        }

        /// Load a single photo from a PHPickerResult.
        /// Attempts to load raw Data first (to preserve EXIF), then falls back to UIImage.
        private func loadPhoto(from result: PHPickerResult) async -> PipelinePhoto? {
            let provider = result.itemProvider

            // Try loading raw data first (preserves EXIF)
            if let dataPhoto = await loadAsData(provider: provider) {
                return dataPhoto
            }

            // Fallback: load as UIImage (EXIF may be stripped)
            return await loadAsUIImage(provider: provider)
        }

        /// Load photo as raw Data to preserve EXIF metadata.
        private func loadAsData(provider: NSItemProvider) async -> PipelinePhoto? {
            // Try common UTTypes in order of preference
            let typeIdentifiers = [
                "public.jpeg",
                "public.heic",
                "public.png",
                "public.tiff",
                "public.image"
            ]

            for typeId in typeIdentifiers {
                guard provider.hasItemConformingToTypeIdentifier(typeId) else { continue }

                if let photo = await loadData(provider: provider, typeIdentifier: typeId) {
                    return photo
                }
            }

            return nil
        }

        /// Load data for a specific type identifier.
        /// A2: Removed inline ImageCompressor.compress() call — compression is now handled
        /// uniformly by PhotoPickerViewModel.compressUncompressedPhotos() after add.
        private func loadData(
            provider: NSItemProvider,
            typeIdentifier: String
        ) async -> PipelinePhoto? {
            await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                    guard let data = data, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let image = UIImage(data: data) else {
                        continuation.resume(returning: nil)
                        return
                    }

                    // Extract EXIF from raw data (before any UIImage conversion)
                    let exif = EXIFExtractor.extract(from: data)

                    let photo = PipelinePhoto(source: .library, image: image, exif: exif)
                    continuation.resume(returning: photo)
                }
            }
        }

        /// Fallback: load as UIImage (may lose EXIF).
        private func loadAsUIImage(provider: NSItemProvider) async -> PipelinePhoto? {
            guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }

            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    guard let image = object as? UIImage, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }

                    // Extract what EXIF we can from the UIImage's JPEG representation
                    let exif = EXIFExtractor.extract(from: image)

                    let photo = PipelinePhoto(source: .library, image: image, exif: exif)
                    continuation.resume(returning: photo)
                }
            }
        }
    }
}

// MARK: - Photo Loading Overlay

/// Full-screen blurred overlay shown on the picker while photos are loading (A3).
private struct PhotoLoadingOverlay: View {
    let photoCount: Int

    var body: some View {
        ZStack {
            // Blur background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Loading \(photoCount) photo\(photoCount == 1 ? "" : "s")…")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Please wait")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
