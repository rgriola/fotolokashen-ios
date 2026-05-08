//
//  EditLocationViewModel.swift
//  fotolokashen
//
//  Phase 2a-3: form state + change tracking + save pipeline for `EditLocationView`.
//
//  Owns 16 published form fields, parsed tags, photo loading, and the multi-step
//  save (delete marked photos → PATCH location). Behavior parity with the inline
//  `populateForm` / `loadPhotos` / `saveChanges` that previously lived in the view.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class EditLocationViewModel: ObservableObject {

    // MARK: - Source of Truth

    let location: Location

    // MARK: - Form State (Basic Info)

    @Published var locationName: String = ""
    @Published var locationType: String = "OTHER"
    @Published var notes: String = ""
    @Published var details: String = ""   // Maps to Location.details (free-text from iOS Create form)

    // MARK: - Form State (Production Details)

    @Published var productionNotes: String = ""
    @Published var entryPoint: String = ""
    @Published var parking: String = ""
    @Published var access: String = ""
    @Published var indoorOutdoor: String = ""
    @Published var isPermanent: Bool = false

    // MARK: - Form State (Production Date)

    @Published var hasProductionDate: Bool = false
    @Published var productionDate: Date = Date()

    // MARK: - Form State (UserSave fields)

    @Published var isFavorite: Bool = false
    @Published var personalRating: Double = 0
    @Published var color: String = ""
    @Published var caption: String = ""
    @Published var tagsText: String = ""  // comma-separated

    // MARK: - Photos State

    @Published var photos: [DetailPhoto] = []
    @Published var isLoadingPhotos: Bool = true
    @Published var photosToDelete: [Int] = []

    // MARK: - Save State

    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    // MARK: - Field Limits (mirror server)

    static let nameLimit = 50
    static let textLimit200 = 200
    static let textLimit500 = 500

    // MARK: - Init

    init(location: Location) {
        self.location = location
        populateForm()
    }

    // MARK: - Computed

    var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var canSave: Bool {
        !isSaving && !locationName.isEmpty
    }

    // MARK: - Form Population

    /// Populate form fields from the existing location data.
    private func populateForm() {
        locationName = location.name
        locationType = location.type ?? "OTHER"
        notes = location.notes ?? ""
        details = location.details ?? ""   // Populate from the `details` field (iOS Create form)
        productionNotes = location.productionNotes ?? ""
        entryPoint = location.entryPoint ?? ""
        parking = location.parking ?? ""
        access = location.access ?? ""
        indoorOutdoor = location.indoorOutdoor ?? ""
        isPermanent = location.isPermanent ?? false
        isFavorite = location.isFavorite ?? false
        personalRating = location.personalRating ?? 0
        color = location.color ?? ""
        caption = location.caption ?? ""
        tagsText = (location.tags ?? []).joined(separator: ", ")

        if let date = location.productionDate {
            hasProductionDate = true
            productionDate = date
        } else {
            hasProductionDate = false
        }
    }

    // MARK: - Photos

    /// Load photos for this location.
    func loadPhotos() async {
        do {
            let response: PhotosResponse = try await APIClient.shared.get(
                "/api/locations/\(location.id)/photos"
            )
            self.photos = response.photos
            self.isLoadingPhotos = false
        } catch {
            #if DEBUG
            print("[EditLocationViewModel] Failed to load photos: \(error)")
            #endif
            self.isLoadingPhotos = false
        }
    }

    func markPhotoForDeletion(_ id: Int) {
        if !photosToDelete.contains(id) {
            photosToDelete.append(id)
        }
    }

    func undoAllPhotoDeletions() {
        photosToDelete.removeAll()
    }

    // MARK: - Field Trimming Helpers

    /// Apply the per-field character limits — call from `.onChange` modifiers in the view.
    func enforceLimits() {
        if locationName.count > Self.nameLimit { locationName = String(locationName.prefix(Self.nameLimit)) }
        if details.count > Self.textLimit500 { details = String(details.prefix(Self.textLimit500)) }
        if productionNotes.count > Self.textLimit500 { productionNotes = String(productionNotes.prefix(Self.textLimit500)) }
        if entryPoint.count > Self.textLimit200 { entryPoint = String(entryPoint.prefix(Self.textLimit200)) }
        if parking.count > Self.textLimit200 { parking = String(parking.prefix(Self.textLimit200)) }
        if access.count > Self.textLimit200 { access = String(access.prefix(Self.textLimit200)) }
        if notes.count > Self.textLimit500 { notes = String(notes.prefix(Self.textLimit500)) }
        if caption.count > Self.textLimit200 { caption = String(caption.prefix(Self.textLimit200)) }
    }

    // MARK: - Save

    /// Save all changes. Returns the updated `Location` on success, `nil` on failure.
    func saveChanges() async -> Location? {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Build production date string (ISO 8601 full-date)
        var productionDateString: String?
        if hasProductionDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            productionDateString = formatter.string(from: productionDate)
        }

        let request = UpdateLocationRequest(
            name: locationName,
            notes: notes.isEmpty ? nil : notes,
            type: locationType,
            productionDate: productionDateString,
            productionNotes: productionNotes.isEmpty ? nil : productionNotes,
            entryPoint: entryPoint.isEmpty ? nil : entryPoint,
            parking: parking.isEmpty ? nil : parking,
            access: access.isEmpty ? nil : access,
            indoorOutdoor: indoorOutdoor.isEmpty ? nil : indoorOutdoor,
            isPermanent: isPermanent,
            details: details.isEmpty ? nil : details,   // Round-trip the iOS Create form Details field
            tags: parsedTags.isEmpty ? nil : parsedTags,
            isFavorite: isFavorite,
            personalRating: personalRating > 0 ? personalRating : nil,
            color: color.isEmpty ? nil : color
        )

        // Step 1: Delete marked photos
        for photoId in photosToDelete {
            let success = await LocationStore.shared.deletePhoto(photoId: photoId, from: location)
            if !success {
                #if DEBUG
                print("[EditLocationViewModel] Failed to delete photo \(photoId)")
                #endif
            }
        }

        // Step 2: Update location fields
        if let updated = await LocationStore.shared.updateLocation(location, request: request) {
            return updated
        } else {
            errorMessage = LocationStore.shared.errorMessage
            return nil
        }
    }
}
