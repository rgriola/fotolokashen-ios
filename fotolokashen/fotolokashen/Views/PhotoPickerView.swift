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
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                onPhotosPicked([])
                return
            }

            Task {
                var photos: [PipelinePhoto] = []

                for result in results {
                    guard let photo = await loadPhoto(from: result) else { continue }
                    photos.append(photo)
                }

                await MainActor.run {
                    onPhotosPicked(photos)
                }
            }
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

                    var photo = PipelinePhoto(source: .library, image: image, exif: exif)
                    // Store compressed data early if JPEG
                    if typeIdentifier == "public.jpeg" {
                        photo.compressedData = ImageCompressor.compress(image)
                    }

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
