//
//  CreateLocationViewModel.swift
//  fotolokashen
//
//  Phase 2a-4: form state + sanitization + geocoding + multi-photo save pipeline
//  for `CreateLocationView`.
//
//  Behavior parity: 1:1 extraction of `loadAddress`, `saveLocation`, and
//  `uploadRemainingPhotos` from the original view, plus the inline `stripURLs`
//  / state-abbreviation / short-zip helpers. The view continues to own
//  `PhotoPickerViewModel` (`photoViewModel`) and passes it into `save(using:)`
//  so the upload progress state remains driven by that pipeline VM.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation
import UIKit

@MainActor
final class CreateLocationViewModel: ObservableObject {

    // MARK: - Published Form State

    @Published var locationName: String = ""
    @Published var locationDetails: String = ""
    @Published var locationType: String = "BROLL"

    @Published var productionDate: Date?
    @Published var hasProductionDate: Bool = false

    // MARK: - Published Geocoding State

    @Published var isLoadingAddress: Bool = true
    @Published var geocodedAddressData: GeocodedAddress?

    // MARK: - Published GPS Spread

    @Published var spreadResult: GPSSpreadAnalyzer.SpreadResult?

    // MARK: - Published Save State

    @Published var createdLocation: Location?
    @Published var showingSuccess: Bool = false

    // MARK: - Static / Constant

    /// Location types presented in the picker (matching web app, excluding admin-only types).
    static let locationTypes: [String] = [
        "BROLL",
        "STORY",
        "INTERVIEW",
        "LIVE ANCHOR",
        "REPORTER LIVE",
        "STAKEOUT",
        "DRONE",
        "SCENE",
        "EVENT",
        "BATHROOM",
        "OTHER"
    ]

    static let nameLimit = 50
    static let detailsLimit = 500

    // MARK: - Dependencies

    let photoLocation: CLLocation?
    let locationService: LocationService

    init(photoLocation: CLLocation?, locationService: LocationService? = nil) {
        self.photoLocation = photoLocation
        // Construct inside MainActor init body to satisfy Swift 6 isolation.
        self.locationService = locationService ?? LocationService()
    }

    // MARK: - Validation

    /// True when the form has the minimum required fields and at least one photo.
    func canSave(photoCount: Int) -> Bool {
        !locationName.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationDetails.trimmingCharacters(in: .whitespaces).isEmpty
            && photoLocation != nil
            && photoCount > 0
    }

    /// Apply hard caps to text fields — call from `.onChange` handlers in the view.
    func enforceLimits() {
        if locationName.count > Self.nameLimit {
            locationName = String(locationName.prefix(Self.nameLimit))
        }
        if locationDetails.count > Self.detailsLimit {
            locationDetails = String(locationDetails.prefix(Self.detailsLimit))
        }
    }

    /// Toggle handler for `hasProductionDate` — keeps `productionDate` in sync.
    func didChangeHasProductionDate(_ newValue: Bool) {
        if !newValue {
            productionDate = nil
        } else if productionDate == nil {
            productionDate = Date()
        }
    }

    // MARK: - GPS Spread

    /// Analyze GPS spread across the seeded photos. No-op if fewer than 2 photos.
    func analyzeSpread(photos: [PipelinePhoto]) {
        guard photos.count >= 2 else { return }
        spreadResult = GPSSpreadAnalyzer.analyze(photos: photos)
    }

    // MARK: - Geocoding

    /// Reverse-geocode `photoLocation` into `geocodedAddressData`.
    func loadAddress() async {
        guard let location = photoLocation else {
            isLoadingAddress = false
            return
        }
        do {
            let geocoded = try await locationService.getGeocodedAddress(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            geocodedAddressData = geocoded
            isLoadingAddress = false
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[CreateLocationViewModel] Geocoding failed: \(error.localizedDescription)")
            }
            #endif
            isLoadingAddress = false
        }
    }

    // MARK: - Address Display Helpers

    /// Returns the 2-letter state abbreviation (uppercased), or nil if absent.
    /// Google returns shortName; Apple may return full name — we keep full names as-is.
    func stateAbbr(_ state: String?) -> String? {
        guard let s = state, !s.isEmpty else { return nil }
        if s.count == 2 { return s.uppercased() }
        return s
    }

    /// Strip ZIP+4 suffix and return a 5-digit ZIP, or nil.
    func shortZip(_ zip: String?) -> String? {
        guard let z = zip, !z.isEmpty else { return nil }
        let base = z.split(separator: "-").first.map(String.init) ?? z
        let digits = base.filter { $0.isNumber }
        guard digits.count >= 5 else { return digits.isEmpty ? nil : digits }
        return String(digits.prefix(5))
    }

    // MARK: - Sanitization

    /// Strips http://, https://, and www. URLs from a string. Defense-in-depth
    /// alongside the server's `sanitizeUserInput`.
    private func stripURLs(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"https?://\S+|www\.\S+"#,
            options: .caseInsensitive
        ) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func sanitizedName() -> String {
        stripURLs(
            locationName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        )
    }

    private func sanitizedDetails() -> String {
        stripURLs(
            locationDetails
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        )
    }

    // MARK: - Save

    /// Save the location and upload all photos.
    /// Drives `photoViewModel.isUploading` / `uploadProgress` for additional photos.
    /// Sets `createdLocation` and `showingSuccess` on success.
    func save(using photoViewModel: PhotoPickerViewModel) async {
        let name = sanitizedName()
        let details = sanitizedDetails()
        guard !name.isEmpty, !details.isEmpty else { return }

        #if DEBUG
        print("[CreateLocation] Saving '\(name)' with \(photoViewModel.photos.count) photo(s)")
        #endif

        guard let location = photoLocation else { return }

        let firstPhoto = photoViewModel.photos.first?.originalImage

        // Fall back to a coordinate-only "address" if reverse-geocoding failed.
        let geocodedAddress: GeocodedAddress
        if let existing = geocodedAddressData {
            geocodedAddress = existing
        } else {
            let coordinateString = String(format: "%.6f, %.6f",
                                          location.coordinate.latitude,
                                          location.coordinate.longitude)
            geocodedAddress = GeocodedAddress(
                placeId: "photo-\(Date().timeIntervalSince1970)",
                formattedAddress: coordinateString,
                streetNumber: nil,
                street: nil,
                city: nil,
                state: nil,
                zipcode: nil
            )
        }

        do {
            // Step 1: Create location with the first photo
            let createdLoc = try await locationService.createLocation(
                name: name,
                type: locationType,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                geocodedAddress: geocodedAddress,
                photo: firstPhoto ?? UIImage(),
                photoLocation: location,
                details: details,
                productionDate: productionDate
            )

            // Step 2: Upload remaining photos (2..N) using the pipeline VM's progress state.
            if photoViewModel.photos.count > 1 {
                let remainingPhotos = Array(photoViewModel.photos.dropFirst())
                _ = await uploadRemainingPhotos(
                    remainingPhotos,
                    locationId: createdLoc.id,
                    location: location,
                    photoViewModel: photoViewModel
                )
            }

            #if DEBUG
            print("[CreateLocation] ✅ Created location \(createdLoc.id) with \(photoViewModel.photos.count) photo(s)")
            #endif

            createdLocation = createdLoc
            showingSuccess = true
        } catch {
            #if DEBUG
            print("[CreateLocation] ❌ Failed: \(error)")
            #endif
            ErrorPresenter.shared.present(
                message: "Couldn't create location: \(error.localizedDescription)"
            )
        }
    }

    /// Upload remaining photos sequentially, updating `photoViewModel.uploadProgress`.
    private func uploadRemainingPhotos(
        _ photos: [PipelinePhoto],
        locationId: Int,
        location: CLLocation,
        photoViewModel: PhotoPickerViewModel
    ) async -> [Photo] {
        photoViewModel.isUploading = true
        photoViewModel.uploadProgress = 0.0
        defer { photoViewModel.isUploading = false }

        let uploader = PhotoUploadService()
        var uploaded: [Photo] = []
        let total = Double(photos.count)

        for (index, pipelinePhoto) in photos.enumerated() {
            do {
                let photo = try await uploader.uploadPhoto(
                    image: pipelinePhoto.originalImage,
                    locationId: locationId,
                    location: location,
                    caption: pipelinePhoto.caption,
                    exifMetadata: pipelinePhoto.exifMetadata
                )
                uploaded.append(photo)
                photoViewModel.uploadProgress = Double(index + 1) / total

                #if DEBUG
                print("[CreateLocation] Uploaded photo \(index + 1)/\(Int(total))")
                #endif
            } catch {
                #if DEBUG
                print("[CreateLocation] Failed to upload photo \(index + 1): \(error)")
                #endif
                // Continue with remaining photos
            }
        }

        return uploaded
    }
}
