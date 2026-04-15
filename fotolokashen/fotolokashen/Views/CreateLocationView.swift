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
            ScrollView {
                VStack(spacing: 20) {
                    // Photo grid (multi-photo)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Photos")
                                .font(.headline)
                            Spacer()
                            if photoViewModel.isCompressing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Compressing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        PhotoGridView(
                            photos: photoViewModel.photos,
                            maxPhotos: photoViewModel.maxPhotos,
                            onAddTapped: {
                                photoViewModel.showPicker = true
                            },
                            onRemovePhoto: { id in
                                photoViewModel.removePhoto(id: id)
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Form fields
                    VStack(alignment: .leading, spacing: 16) {
                        // Location Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location Name")
                                .font(.headline)
                            
                            TextField("Enter location name", text: $locationName)
                                .textFieldStyle(.roundedBorder)
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
                                    .foregroundColor(locationName.count >= 50 ? .destructive : .secondary)
                            }
                        }
                        
                        // Location Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.headline)
                            
                            Picker("Type", selection: $locationType) {
                                ForEach(locationTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.blue)
                        }
                        
                        // Production Date (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Production Date")
                                .font(.headline)
                            
                            Toggle("Set Production Date", isOn: $hasProductionDate)
                                .tint(.blue)
                                .onChange(of: hasProductionDate) { _, newValue in
                                    if !newValue {
                                        productionDate = nil
                                    } else if productionDate == nil {
                                        productionDate = Date()
                                    }
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
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // GPS Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("GPS Information")
                                .font(.headline)
                            
                            if let location = photoLocation {
                                // Address
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.brand)
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Address")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if isLoadingAddress {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Text(address)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemFill))
                                .cornerRadius(8)
                                
                                // Coordinates
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.success)
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Coordinates")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(String(format: "%.3f, %.3f", 
                                                  location.coordinate.latitude,
                                                  location.coordinate.longitude))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding()
                                .background(Color(.systemFill))
                                .cornerRadius(8)
                                
                                // Accuracy
                                HStack(spacing: 4) {
                                    Image(systemName: "scope")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Accuracy: ±\(Int(location.horizontalAccuracy))m")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("No GPS data available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.warning.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    
                    // Save button
                    Button(action: {
                        Task {
                            await saveLocation()
                        }
                    }) {
                        HStack {
                            if locationService.isLoading || photoViewModel.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                if photoViewModel.isUploading {
                                    Text("Uploading \(Int(photoViewModel.uploadProgress * 100))%")
                                } else {
                                    Text("Creating...")
                                }
                            } else {
                                Image(systemName: AppIcons.checkmark)
                                Text("Create Location")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.brand : Color(.systemGray3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || locationService.isLoading || photoViewModel.isUploading)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    // Error message
                    if let error = locationService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.destructive)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Create Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
