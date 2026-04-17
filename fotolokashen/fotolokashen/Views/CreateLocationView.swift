import SwiftUI
import CoreLocation

/// Form for creating a new location with captured photo
///
// REVIEW: Missing features compared to web app's create-with-photo flow:
// 1. No Photo Library picker — only accepts camera-captured UIImage. Add PHPickerViewController.
// 2. No multi-photo support — single photo only. Web supports up to 20 photos at creation.
// 3. No caption field — web app supports captions at creation time.
// 4. No UserSave fields (tags, personalRating, isFavorite, color) — must edit post-create.
// 5. GPS source is always device CLLocation — should also extract GPS from photo EXIF
//    (like web does) and prefer photo GPS when available.
struct CreateLocationView: View {
    
    @StateObject private var locationService = LocationService()
    @StateObject private var photoViewModel = PhotoPickerViewModel()
    @Environment(\.dismiss) var dismiss
    
    /// Initial photo from the camera (optional — user can also add from library)
    let initialPhoto: UIImage?
    let photoLocation: CLLocation?
    var onLocationCreated: ((Location) -> Void)?
    
    /// Legacy initializer: single camera photo (backward compatible)
    init(
        photo: UIImage,
        photoLocation: CLLocation?,
        onLocationCreated: ((Location) -> Void)? = nil
    ) {
        self.initialPhoto = photo
        self.photoLocation = photoLocation
        self.onLocationCreated = onLocationCreated
    }

    /// New initializer: start with Photo Library (no initial photo)
    init(
        photoLocation: CLLocation?,
        onLocationCreated: ((Location) -> Void)? = nil
    ) {
        self.initialPhoto = nil
        self.photoLocation = photoLocation
        self.onLocationCreated = onLocationCreated
    }
    
    @State private var locationName = ""
    @State private var locationDetails = ""
    @State private var locationType = "BROLL"
    @State private var productionDate: Date?
    @State private var hasProductionDate = false
    @State private var isLoadingAddress = true
    @State private var showingSuccess = false
    @State private var createdLocation: Location?
    @State private var geocodedAddressData: GeocodedAddress?
    
    // Location types (matching web app)
    private let locationTypes = [
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
        // Note: Admin-only types (HQ, BUREAU, REMOTE STAFF, STORAGE) 
        // should be added based on user role in future
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // ── Photos ───────────────────────────────────────────────
                Section {
                    if photoViewModel.isCompressing {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Compressing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
                    }

                    PhotoGridView(
                        photos: photoViewModel.photos,
                        maxPhotos: photoViewModel.maxPhotos,
                        onAddTapped: { photoViewModel.showPicker = true },
                        onRemovePhoto: { id in photoViewModel.removePhoto(id: id) }
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                // ── Location Info ─────────────────────────────────────────
                Section("Location Info") {
                    // Name (required, 50 chars)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Location Name (required)", text: $locationName)
                            .autocapitalization(.words)
                            .submitLabel(.next)
                            .onChange(of: locationName) { _, newValue in
                                // Hard cap — collapse excess whitespace as you type
                                var cleaned = newValue
                                if cleaned.count > 50 { cleaned = String(cleaned.prefix(50)) }
                                if cleaned != newValue { locationName = cleaned }
                            }
                        HStack {
                            if locationName.trimmingCharacters(in: .whitespaces).isEmpty && !locationName.isEmpty {
                                Text("Name cannot be blank")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                            if locationName.count > 35 {
                                Text("\(locationName.count)/50")
                                    .font(.caption)
                                    .foregroundStyle(locationName.count >= 50 ? .red : .secondary)
                            }
                        }
                    }

                    // Details (required, 500 chars)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Location Details (required)", text: $locationDetails, axis: .vertical)
                            .lineLimit(3...6)
                            .autocapitalization(.sentences)
                            .submitLabel(.done)
                            .onChange(of: locationDetails) { _, newValue in
                                if newValue.count > 500 { locationDetails = String(newValue.prefix(500)) }
                            }
                        HStack {
                            if locationDetails.trimmingCharacters(in: .whitespaces).isEmpty && !locationDetails.isEmpty {
                                Text("Details cannot be blank")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                            if locationDetails.count > 400 {
                                Text("\(locationDetails.count)/500")
                                    .font(.caption)
                                    .foregroundStyle(locationDetails.count >= 500 ? .red : .secondary)
                            }
                        }
                    }

                    Picker("Type", selection: $locationType) {
                        ForEach(locationTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                // ── Production Date ───────────────────────────────────────
                Section("Production Date") {
                    Toggle("Production Date", isOn: $hasProductionDate)
                        .tint(.brandPurple)
                        .onChange(of: hasProductionDate) { _, newValue in
                            if !newValue { productionDate = nil }
                            else if productionDate == nil { productionDate = Date() }
                        }

                    if hasProductionDate {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { productionDate ?? Date() },
                                set: { productionDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                    }
                }

                // ── GPS Information ───────────────────────────────────────
                Section("GPS Information") {
                    if photoLocation != nil {
                        if isLoadingAddress {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.9)
                                Text("Locating address…")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        } else {
                            // Postal address layout
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.brand)
                                    .frame(width: 20)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    if let geo = geocodedAddressData {
                                        // Line 1: street number + street
                                        if let street = geo.fullStreet {
                                            Text(street)
                                                .font(.subheadline)
                                        }
                                        // Line 2: City, ST
                                        let cityState = [geo.city, stateAbbr(geo.state)]
                                            .compactMap { $0?.isEmpty == false ? $0 : nil }
                                            .joined(separator: ", ")
                                        if !cityState.isEmpty {
                                            Text(cityState)
                                                .font(.subheadline)
                                        }
                                        // Line 3: ZIP (5-digit only)
                                        if let zip = shortZip(geo.zipcode) {
                                            Text(zip)
                                                .font(.subheadline)
                                        }
                                    } else {
                                        Text("Address unavailable")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Label("No GPS data available", systemImage: "location.slash")
                            .foregroundStyle(.orange)
                    }
                }

                // ── Save Button ───────────────────────────────────────────
                Section {
                    Button(action: { Task { await saveLocation() } }) {
                        HStack {
                            Spacer()
                            if locationService.isLoading || photoViewModel.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 6)
                                Text(photoViewModel.isUploading
                                     ? "Uploading \(Int(photoViewModel.uploadProgress * 100))%"
                                     : "Creating…")
                            } else {
                                Image(systemName: AppIcons.checkmark)
                                    .padding(.trailing, 4)
                                Text("Create Location")
                            }
                            Spacer()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(canSave ? Color.brand : Color(.systemGray3))
                    .disabled(!canSave || locationService.isLoading || photoViewModel.isUploading)
                }

                // Error message
                if let error = locationService.errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .navigationTitle("Create Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }

        .task {
            // Seed the initial camera photo into the pipeline
            if let initial = initialPhoto, photoViewModel.photos.isEmpty {
                photoViewModel.addCameraPhoto(image: initial, location: photoLocation)
            }
            await loadAddress()
        }
        .sheet(isPresented: $photoViewModel.showPicker) {
            let remaining = photoViewModel.maxPhotos - photoViewModel.photos.count
            PhotoPickerView(selectionLimit: max(remaining, 1)) { newPhotos in
                photoViewModel.addPhotos(newPhotos)
            }
        }
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") {
                if let location = createdLocation {
                    onLocationCreated?(location)
                }
                dismiss()
            }
        } message: {
            Text("Location created successfully!")
        }
    }
    
    // MARK: - Computed Properties

    private var canSave: Bool {
        !locationName.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationDetails.trimmingCharacters(in: .whitespaces).isEmpty
            && photoLocation != nil
            && !photoViewModel.photos.isEmpty
    }

    /// Returns the 2-letter state abbreviation (uppercased), or nil if absent.
    /// Google already returns shortName; Apple may return full name, so we take first 2 chars
    /// only when the string is exactly 2 characters (proper abbrev) to avoid truncating full names.
    private func stateAbbr(_ state: String?) -> String? {
        guard let s = state, !s.isEmpty else { return nil }
        // Google shortName is already 2-letter; Apple administrativeArea may be full name
        if s.count == 2 { return s.uppercased() }
        // For Apple full names we keep as-is (no truncation of "New York" → "Ne")
        return s
    }

    /// Returns only the 5-digit base ZIP, dropping any "-XXXX" extension.
    private func shortZip(_ zip: String?) -> String? {
        guard let z = zip, !z.isEmpty else { return nil }
        // Strip anything after a hyphen, then take first 5 digits
        let base = z.split(separator: "-").first.map(String.init) ?? z
        let digits = base.filter { $0.isNumber }
        guard digits.count >= 5 else { return digits.isEmpty ? nil : digits }
        return String(digits.prefix(5))
    }
    
    // MARK: - Methods
    
    private func loadAddress() async {
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
                print("[CreateLocation] Geocoding failed: \(error.localizedDescription)")
            }
            #endif
            isLoadingAddress = false
        }
    }
    
    private func saveLocation() async {
        // ── Sanitize inputs before saving ─────────────────────────────────
        // Trim leading/trailing whitespace, collapse multiple internal spaces
        let sanitizedName = locationName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let sanitizedDetails = locationDetails
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        // Guard: both fields must be non-empty after sanitization
        guard !sanitizedName.isEmpty, !sanitizedDetails.isEmpty else { return }

        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[CreateLocation] Saving '\(sanitizedName)' with \(photoViewModel.photos.count) photo(s)")
        }
        #endif

        guard let location = photoLocation else { return }

        let firstPhoto = photoViewModel.photos.first?.originalImage

        // Create fallback geocoded address using coordinates if geocoding failed
        let geocodedAddress: GeocodedAddress
        if let existingGeocodedData = geocodedAddressData {
            geocodedAddress = existingGeocodedData
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
            let createdLoc = try await locationService.createLocation(
                name: sanitizedName,
                type: locationType,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                geocodedAddress: geocodedAddress,
                photo: firstPhoto ?? UIImage(),
                photoLocation: location,
                productionDate: productionDate
            )

            // Upload remaining photos (index 1+) individually
            if photoViewModel.photos.count > 1 {
                let uploader = PhotoUploadService()
                for pipelinePhoto in photoViewModel.photos.dropFirst() {
                    do {
                        _ = try await uploader.uploadPhoto(
                            image: pipelinePhoto.originalImage,
                            locationId: createdLoc.id,
                            location: location,
                            caption: pipelinePhoto.caption,
                            exifMetadata: pipelinePhoto.exifMetadata
                        )
                    } catch {
                        #if DEBUG
                        if ConfigLoader.shared.enableDebugLogging {
                            print("[CreateLocation] Failed to upload extra photo: \(error)")
                        }
                        #endif
                    }
                }
            }

            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[CreateLocation] ✅ Created location \(createdLoc.id) with \(photoViewModel.photos.count) photo(s)")
            }
            #endif

            createdLocation = createdLoc
            showingSuccess = true

        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[CreateLocation] ❌ Failed: \(error)")
            }
            #endif
        }
    }
}

// MARK: - Preview

#Preview {
    CreateLocationView(
        photo: UIImage(systemName: "photo.fill")!,
        photoLocation: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
}
