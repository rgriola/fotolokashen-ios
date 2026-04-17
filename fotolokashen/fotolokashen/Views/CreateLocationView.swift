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
    @State private var locationType = "BROLL"
    @State private var productionDate: Date?  // Optional production date
    @State private var hasProductionDate = false  // Toggle for setting date
    @State private var address = "Loading address..."
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
                    HStack {
                        Text("Photos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if photoViewModel.isCompressing {
                            HStack(spacing: 4) {
                                ProgressView().scaleEffect(0.7)
                                Text("Compressing…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                    PhotoGridView(
                        photos: photoViewModel.photos,
                        maxPhotos: photoViewModel.maxPhotos,
                        onAddTapped: { photoViewModel.showPicker = true },
                        onRemovePhoto: { id in photoViewModel.removePhoto(id: id) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                }

                // ── Location Info ─────────────────────────────────────────
                Section("Location Info") {
                    TextField("Location Name", text: $locationName)
                        .autocapitalization(.words)
                        .submitLabel(.done)
                        .onChange(of: locationName) { _, newValue in
                            if newValue.count > 50 {
                                locationName = String(newValue.prefix(50))
                            }
                        }
                    if locationName.count > 40 {
                        Text("\(locationName.count)/50")
                            .font(.caption)
                            .foregroundStyle(locationName.count >= 50 ? .red : .secondary)
                    }

                    Picker("Type", selection: $locationType) {
                        ForEach(locationTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                // ── Production Date ───────────────────────────────────────
                Section("Production Date") {
                    Toggle("Set Production Date", isOn: $hasProductionDate)
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
                    if let location = photoLocation {
                        // Address
                        LabeledContent {
                            if isLoadingAddress {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text(address)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        } label: {
                            Label("Address", systemImage: "mappin.and.ellipse")
                        }

                        // Coordinates
                        LabeledContent {
                            Text(String(format: "%.4f, %.4f",
                                        location.coordinate.latitude,
                                        location.coordinate.longitude))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Coordinates", systemImage: "location.fill")
                        }

                        // Accuracy
                        LabeledContent {
                            Text("±\(Int(location.horizontalAccuracy))m")
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Accuracy", systemImage: "scope")
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
        !locationName.isEmpty && photoLocation != nil && !photoViewModel.photos.isEmpty
    }
    
    // MARK: - Methods
    
    private func loadAddress() async {
        guard let location = photoLocation else {
            address = "No GPS data"
            isLoadingAddress = false
            return
        }
        
        do {
            let geocoded = try await locationService.getGeocodedAddress(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            geocodedAddressData = geocoded
            address = geocoded.formattedAddress
            isLoadingAddress = false
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[CreateLocation] Geocoding failed: \(error.localizedDescription)")
            }
            #endif
            address = "Address unavailable"
            isLoadingAddress = false
        }
    }
    
    private func saveLocation() async {
        #if DEBUG
        if ConfigLoader.shared.enableDebugLogging {
            print("[CreateLocation] Saving with \(photoViewModel.photos.count) photo(s)")
        }
        #endif

        guard let location = photoLocation else { return }

        // Use first photo for the initial location creation (backward compatible)
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
                name: locationName,
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
