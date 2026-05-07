import SwiftUI
import CoreLocation

/// Form for creating a new location with one or more photos.
///
/// Phase 2a-4: form state, sanitization, geocoding, GPS spread analysis, and
/// the multi-photo save pipeline live in `CreateLocationViewModel`. The view
/// keeps `PhotoPickerViewModel` as a separate `@StateObject` (it's the photo
/// pipeline VM) and passes it to the create VM at save time.
///
// REVIEW: Still missing — caption, tags, personalRating, isFavorite, color at
// create time. `CreateLocationRequest` doesn't carry these fields and the
// server's POST /api/locations doesn't accept them, so adding them requires
// either (a) a CREATE → PATCH chain client-side, or (b) a server-side schema
// change. Tracked as a follow-up to Phase 2a.
struct CreateLocationView: View {

    @StateObject private var viewModel: CreateLocationViewModel
    @StateObject private var photoViewModel = PhotoPickerViewModel()
    @Environment(\.dismiss) var dismiss

    /// Initial photo from the camera (optional — user can also add from library)
    let initialPhoto: UIImage?
    let initialLibraryPhotos: [PipelinePhoto]?
    let initialSessionCaptures: [SessionCapture]?
    var onLocationCreated: ((Location) -> Void)?

    /// Legacy initializer: single camera photo (backward compatible)
    init(
        photo: UIImage,
        photoLocation: CLLocation?,
        onLocationCreated: ((Location) -> Void)? = nil
    ) {
        self.initialPhoto = photo
        self.initialLibraryPhotos = nil
        self.initialSessionCaptures = nil
        self.onLocationCreated = onLocationCreated
        _viewModel = StateObject(wrappedValue: CreateLocationViewModel(photoLocation: photoLocation))
    }

    /// Initializer: start with Photo Library photos
    init(
        libraryPhotos: [PipelinePhoto],
        photoLocation: CLLocation?,
        onLocationCreated: ((Location) -> Void)? = nil
    ) {
        self.initialPhoto = nil
        self.initialLibraryPhotos = libraryPhotos
        self.initialSessionCaptures = nil
        self.onLocationCreated = onLocationCreated
        _viewModel = StateObject(wrappedValue: CreateLocationViewModel(photoLocation: photoLocation))
    }

    /// Initializer: start with multi-photo camera session captures
    init(
        sessionCaptures: [SessionCapture],
        photoLocation: CLLocation?,
        onLocationCreated: ((Location) -> Void)? = nil
    ) {
        self.initialPhoto = nil
        self.initialLibraryPhotos = nil
        self.initialSessionCaptures = sessionCaptures
        self.onLocationCreated = onLocationCreated
        _viewModel = StateObject(wrappedValue: CreateLocationViewModel(photoLocation: photoLocation))
    }

    /// Initializer: no initial photo (opens with empty grid + picker)
    init(
        photoLocation: CLLocation?,
        onLocationCreated: ((Location) -> Void)? = nil
    ) {
        self.initialPhoto = nil
        self.initialLibraryPhotos = nil
        self.initialSessionCaptures = nil
        self.onLocationCreated = onLocationCreated
        _viewModel = StateObject(wrappedValue: CreateLocationViewModel(photoLocation: photoLocation))
    }

    private var photoLocation: CLLocation? { viewModel.photoLocation }

    var body: some View {
        NavigationStack {
            Form {
                photosSection
                locationInfoSection
                productionDateSection
                gpsSection
                saveSection
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
            // Seed initial photos into the pipeline
            if photoViewModel.photos.isEmpty {
                if let initial = initialPhoto {
                    photoViewModel.addCameraPhoto(image: initial, location: photoLocation)
                } else if let captures = initialSessionCaptures, !captures.isEmpty {
                    let pipelinePhotos = captures.compactMap { $0.toPipelinePhoto() }
                    photoViewModel.addPhotos(pipelinePhotos)
                } else if let libraryPhotos = initialLibraryPhotos, !libraryPhotos.isEmpty {
                    photoViewModel.addPhotos(libraryPhotos)
                }
            }

            // Run GPS spread detection AFTER photos are seeded (A4 — fixes L5)
            if !photoViewModel.photos.isEmpty {
                viewModel.analyzeSpread(photos: photoViewModel.photos)
            }

            await viewModel.loadAddress()
        }
        .sheet(isPresented: $photoViewModel.showPicker) {
            let remaining = photoViewModel.maxPhotos - photoViewModel.photos.count
            PhotoPickerView(selectionLimit: max(remaining, 1)) { newPhotos in
                photoViewModel.addPhotos(newPhotos)
            }
        }
        .alert("Success!", isPresented: $viewModel.showingSuccess) {
            Button("OK") {
                if let location = viewModel.createdLocation {
                    onLocationCreated?(location)
                }
                dismiss()
            }
        } message: {
            Text("Location created successfully!")
        }
    }

    // MARK: - Sections

    private var photosSection: some View {
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
                onRemovePhoto: { id in photoViewModel.removePhoto(id: id) },
                onRetryPhoto: { id in photoViewModel.retryPhoto(id: id) }
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // GPS Spread Info Banner
            if let spread = viewModel.spreadResult, spread.exceedsThreshold {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photos span \(spread.spreadDescription)")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Using first photo's location. You can change this in Edit mode.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var locationInfoSection: some View {
        Section("Location Info") {
            // Name (required, 50 chars)
            VStack(alignment: .leading, spacing: 4) {
                TextField("Location Name (required)", text: $viewModel.locationName)
                    .autocapitalization(.words)
                    .submitLabel(.next)
                    .onChange(of: viewModel.locationName) { _, _ in viewModel.enforceLimits() }
                HStack {
                    if viewModel.locationName.trimmingCharacters(in: .whitespaces).isEmpty
                        && !viewModel.locationName.isEmpty {
                        Text("Name cannot be blank")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    if viewModel.locationName.count > 35 {
                        Text("\(viewModel.locationName.count)/\(CreateLocationViewModel.nameLimit)")
                            .font(.caption)
                            .foregroundStyle(viewModel.locationName.count >= CreateLocationViewModel.nameLimit ? .red : .secondary)
                    }
                }
            }

            // Details (required, 500 chars)
            VStack(alignment: .leading, spacing: 4) {
                TextField("Location Details (required)", text: $viewModel.locationDetails, axis: .vertical)
                    .lineLimit(3...6)
                    .autocapitalization(.sentences)
                    .submitLabel(.done)
                    .onChange(of: viewModel.locationDetails) { _, _ in viewModel.enforceLimits() }
                HStack {
                    if viewModel.locationDetails.trimmingCharacters(in: .whitespaces).isEmpty
                        && !viewModel.locationDetails.isEmpty {
                        Text("Details cannot be blank")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    if viewModel.locationDetails.count > 400 {
                        Text("\(viewModel.locationDetails.count)/\(CreateLocationViewModel.detailsLimit)")
                            .font(.caption)
                            .foregroundStyle(viewModel.locationDetails.count >= CreateLocationViewModel.detailsLimit ? .red : .secondary)
                    }
                }
            }

            Picker("Type", selection: $viewModel.locationType) {
                ForEach(CreateLocationViewModel.locationTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
        }
    }

    private var productionDateSection: some View {
        Section("Production Date") {
            Toggle("Production Date", isOn: $viewModel.hasProductionDate)
                .tint(.brand)
                .onChange(of: viewModel.hasProductionDate) { _, newValue in
                    viewModel.didChangeHasProductionDate(newValue)
                }

            if viewModel.hasProductionDate {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { viewModel.productionDate ?? Date() },
                        set: { viewModel.productionDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
            }
        }
    }

    private var gpsSection: some View {
        Section("GPS Information") {
            if photoLocation != nil {
                if viewModel.isLoadingAddress {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.9)
                        Text("Locating address…")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Color.brand)
                            .frame(width: 20)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            if let geo = viewModel.geocodedAddressData {
                                if let street = geo.fullStreet {
                                    Text(street)
                                        .font(.subheadline)
                                }
                                let cityState = [geo.city, viewModel.stateAbbr(geo.state)]
                                    .compactMap { $0?.isEmpty == false ? $0 : nil }
                                    .joined(separator: ", ")
                                if !cityState.isEmpty {
                                    Text(cityState)
                                        .font(.subheadline)
                                }
                                if let zip = viewModel.shortZip(geo.zipcode) {
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
    }

    private var saveSection: some View {
        Section {
            Button(action: { Task { await viewModel.save(using: photoViewModel) } }) {
                HStack {
                    Spacer()
                    if viewModel.locationService.isLoading || photoViewModel.isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 6)
                        if photoViewModel.isUploading {
                            let uploaded = Int(photoViewModel.uploadProgress * Double(photoViewModel.photos.count - 1))
                            let total = photoViewModel.photos.count - 1
                            Text("Uploading \(uploaded + 1)/\(total)…")
                        } else {
                            Text("Creating…")
                        }
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
            .disabled(!canSave || viewModel.locationService.isLoading || photoViewModel.isUploading)
        }
    }

    // MARK: - Computed Helpers

    private var canSave: Bool {
        viewModel.canSave(photoCount: photoViewModel.photos.count)
    }
}

// MARK: - Preview

#Preview {
    CreateLocationView(
        photo: UIImage(systemName: "photo.fill")!,
        photoLocation: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
}
