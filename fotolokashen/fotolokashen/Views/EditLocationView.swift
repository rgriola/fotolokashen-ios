import SwiftUI
import Kingfisher

/// Edit view for an existing location with all editable fields
///
// REVIEW: State management — this view has 15+ @State vars for form fields.
// Consider extracting into an EditLocationViewModel (@StateObject ObservableObject) that
// holds all form state + change tracking logic. This would:
// - Simplify the view body
// - Make change tracking testable
// - Enable form validation before API calls
struct EditLocationView: View {
    let location: Location
    var onLocationUpdated: ((Location) -> Void)?

    @ObservedObject private var locationStore = LocationStore.shared
    @Environment(\.dismiss) var dismiss

    // MARK: - Form State

    // Basic info
    @State private var locationName: String = ""
    @State private var locationType: String = "OTHER"
    @State private var notes: String = ""

    // Production details
    @State private var productionNotes: String = ""
    @State private var entryPoint: String = ""
    @State private var parking: String = ""
    @State private var access: String = ""
    @State private var indoorOutdoor: String = ""
    @State private var isPermanent: Bool = false

    // Production date
    @State private var hasProductionDate: Bool = false
    @State private var productionDate: Date = Date()

    // UserSave fields
    @State private var isFavorite: Bool = false
    @State private var personalRating: Double = 0
    @State private var color: String = ""
    @State private var caption: String = ""
    @State private var tagsText: String = ""  // Comma-separated

    // Photos
    @State private var photos: [DetailPhoto] = []
    @State private var isLoadingPhotos = true
    @State private var photosToDelete: [Int] = []

    // UI state
    @State private var isSaving = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @State private var showingDeletePhotoConfirmation = false
    @State private var photoToDeleteId: Int?

    // Indoor/Outdoor options
    private let indoorOutdoorOptions = ["", "indoor", "outdoor", "both"]

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Basic Info Section
                Section {
                    TextField("Location Name", text: $locationName)
                        .autocapitalization(.words)
                        .onChange(of: locationName) { _, newValue in
                            if newValue.count > 50 {
                                locationName = String(newValue.prefix(50))
                            }
                        }

                    Picker("Type", selection: $locationType) {
                        ForEach(LocationTypeColors.standardTypes, id: \.self) { type in
                            HStack {
                                Image(systemName: LocationTypeColors.icon(for: type))
                                Text(type)
                            }
                            .tag(type)
                        }
                    }

                    Toggle("Favorite", isOn: $isFavorite)
                        .tint(.yellow)
                } header: {
                    Label("Basic Info", systemImage: "info.circle")
                }

                // MARK: - Production Date Section
                Section {
                    Toggle("Set Production Date", isOn: $hasProductionDate)
                        .tint(.blue)

                    if hasProductionDate {
                        DatePicker(
                            "Date",
                            selection: $productionDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                    }
                } header: {
                    Label("Production Date", systemImage: "calendar")
                }

                // MARK: - Production Details Section
                Section {
                    TextField("Production Notes", text: $productionNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: productionNotes) { _, newValue in
                            if newValue.count > 500 {
                                productionNotes = String(newValue.prefix(500))
                            }
                        }

                    TextField("Entry Point", text: $entryPoint)
                        .onChange(of: entryPoint) { _, newValue in
                            if newValue.count > 200 {
                                entryPoint = String(newValue.prefix(200))
                            }
                        }

                    TextField("Parking", text: $parking)
                        .onChange(of: parking) { _, newValue in
                            if newValue.count > 200 {
                                parking = String(newValue.prefix(200))
                            }
                        }

                    TextField("Access", text: $access)
                        .onChange(of: access) { _, newValue in
                            if newValue.count > 200 {
                                access = String(newValue.prefix(200))
                            }
                        }

                    Picker("Indoor/Outdoor", selection: $indoorOutdoor) {
                        Text("Not Set").tag("")
                        Text("Indoor").tag("indoor")
                        Text("Outdoor").tag("outdoor")
                        Text("Both").tag("both")
                    }

                    Toggle("Permanent Location", isOn: $isPermanent)
                        .tint(.green)
                } header: {
                    Label("Production Details", systemImage: "film")
                }

                // MARK: - Notes & Caption Section
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: notes) { _, newValue in
                            if newValue.count > 500 {
                                notes = String(newValue.prefix(500))
                            }
                        }

                    TextField("Personal Caption", text: $caption)
                        .onChange(of: caption) { _, newValue in
                            if newValue.count > 200 {
                                caption = String(newValue.prefix(200))
                            }
                        }
                } header: {
                    Label("Notes", systemImage: "note.text")
                }

                // MARK: - Tags Section
                Section {
                    TextField("Tags (comma-separated)", text: $tagsText)
                        .autocapitalization(.none)

                    if !parsedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(parsedTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.brand.opacity(0.15))
                                        .foregroundColor(.brand)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    Label("Tags", systemImage: "tag")
                }

                // MARK: - Personal Rating Section
                Section {
                    HStack {
                        Text("Rating")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(personalRating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .onTapGesture {
                                        personalRating = Double(star)
                                    }
                            }
                        }
                    }

                    if personalRating > 0 {
                        Button("Clear Rating") {
                            personalRating = 0
                        }
                        .foregroundColor(.destructive)
                        .font(.caption)
                    }
                } header: {
                    Label("Personal Rating", systemImage: "star")
                }

                // MARK: - Photos Section
                Section {
                    if isLoadingPhotos {
                        HStack {
                            Spacer()
                            ProgressView("Loading photos...")
                            Spacer()
                        }
                    } else if photos.isEmpty {
                        Text("No photos")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(photos) { photo in
                            HStack(spacing: 12) {
                                KFImage(URL(string: photo.thumbnailUrl))
                                    .resizable()
                                    .placeholder {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 60, height: 60)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .foregroundColor(.secondary)
                                            }
                                    }
                                    .onFailureImage(KFCrossPlatformImage(systemName: "photo"))
                                    .fade(duration: 0.2)
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(photo.caption ?? "No caption")
                                        .font(.subheadline)
                                        .lineLimit(1)

                                    if photo.isPrimary == true {
                                        Text("Primary")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.brand.opacity(0.2))
                                            .foregroundColor(.brand)
                                            .clipShape(Capsule())
                                    }
                                }

                                Spacer()

                                if photosToDelete.contains(photo.id) {
                                    Text("Marked for deletion")
                                        .font(.caption2)
                                        .foregroundColor(.destructive)
                                } else {
                                    Button {
                                        photoToDeleteId = photo.id
                                        showingDeletePhotoConfirmation = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.destructive)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }

                        if !photosToDelete.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.warning)
                                Text("\(photosToDelete.count) photo(s) will be deleted on save")
                                    .font(.caption)
                                    .foregroundColor(.warning)
                            }

                            Button("Undo All Photo Deletions") {
                                photosToDelete.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    Label("Photos (\(photos.count - photosToDelete.count))", systemImage: "photo.stack")
                }

                // MARK: - Location Info (Read-Only)
                Section {
                    DetailRow(label: "Address", value: location.address ?? "N/A")
                    DetailRow(label: "Latitude", value: String(format: "%.6f", location.latitude))
                    DetailRow(label: "Longitude", value: String(format: "%.6f", location.longitude))
                    DetailRow(label: "Place ID", value: location.placeId)
                } header: {
                    Label("Location Info (Read-Only)", systemImage: "mappin.and.ellipse")
                }
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || locationName.isEmpty)
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Location updated successfully!")
            }
            .alert("Delete Photo?", isPresented: $showingDeletePhotoConfirmation) {
                Button("Cancel", role: .cancel) {
                    photoToDeleteId = nil
                }
                Button("Mark for Deletion", role: .destructive) {
                    if let id = photoToDeleteId {
                        photosToDelete.append(id)
                    }
                    photoToDeleteId = nil
                }
            } message: {
                Text("This photo will be permanently deleted when you save.")
            }
        }
        .onAppear {
            populateForm()
        }
        .task {
            await loadPhotos()
        }
    }

    // MARK: - Computed Properties

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Methods

    /// Populate form fields from the existing location data
    private func populateForm() {
        locationName = location.name
        locationType = location.type ?? "OTHER"
        notes = location.notes ?? ""
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

    /// Load photos for this location
    private func loadPhotos() async {
        do {
            let response: PhotosResponse = try await APIClient.shared.get(
                "/api/locations/\(location.id)/photos"
            )
            await MainActor.run {
                self.photos = response.photos
                self.isLoadingPhotos = false
            }
        } catch {
            #if DEBUG
            print("[EditLocationView] Failed to load photos: \(error)")
            #endif
            await MainActor.run {
                self.isLoadingPhotos = false
            }
        }
    }

    /// Save all changes
    private func saveChanges() async {
        isSaving = true
        errorMessage = nil

        // Build production date string
        var productionDateString: String?
        if hasProductionDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            productionDateString = formatter.string(from: productionDate)
        }

        // Build update request
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
            tags: parsedTags.isEmpty ? nil : parsedTags,
            isFavorite: isFavorite,
            personalRating: personalRating > 0 ? personalRating : nil,
            color: color.isEmpty ? nil : color
        )

        // Step 1: Delete marked photos
        for photoId in photosToDelete {
            let success = await locationStore.deletePhoto(photoId: photoId, from: location)
            if !success {
                #if DEBUG
                print("[EditLocationView] Failed to delete photo \(photoId)")
                #endif
            }
        }

        // Step 2: Update location fields
        if let updated = await locationStore.updateLocation(location, request: request) {
            await MainActor.run {
                isSaving = false
                onLocationUpdated?(updated)
                showingSuccess = true
            }
        } else {
            await MainActor.run {
                isSaving = false
                errorMessage = locationStore.errorMessage
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditLocationView(
        location: Location(
            id: 1,
            name: "Test Location",
            address: "123 Main St, New York, NY 10001",
            latitude: 40.7128,
            longitude: -74.0060,
            type: "BROLL",
            placeId: "place-123",
            createdAt: "2026-01-20T10:00:00Z",
            photosCount: 3,
            thumbnailUrl: nil,
            userSaveId: 1,
            productionNotes: "Good lighting in the morning",
            isFavorite: true,
            tags: ["sunset", "golden-hour"]
        )
    )
}
