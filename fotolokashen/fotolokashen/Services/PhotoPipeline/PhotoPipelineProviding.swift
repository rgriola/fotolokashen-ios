import Foundation
import UIKit
import CoreLocation
import Combine

/// Phase 1b — Shared surface for the legacy `PhotoPickerViewModel` and the new
/// `PhotoPipelineCoordinator`. Lets `CreateLocationView` (and other consumers)
/// swap implementations behind `ConfigLoader.shared.useNewPhotoPipeline` with
/// a single line change once the new pipeline is ready for production.
///
/// Intentionally minimal — just the surface today's views actually touch.
@MainActor
protocol PhotoPipelineProviding: ObservableObject {
    var photos: [PipelinePhoto] { get }
    var maxPhotos: Int { get }
    var canAddMore: Bool { get }
    var isCompressing: Bool { get }
    var isUploading: Bool { get }
    var uploadProgress: Double { get }
    var showPicker: Bool { get set }

    func addPhotos(_ newPhotos: [PipelinePhoto])
    func addCameraPhoto(image: UIImage, location: CLLocation?)
    func removePhoto(id: UUID)
    func clearPhotos()
}

// MARK: - Conformances

extension PhotoPickerViewModel: PhotoPipelineProviding {}
extension PhotoPipelineCoordinator: PhotoPipelineProviding {}
