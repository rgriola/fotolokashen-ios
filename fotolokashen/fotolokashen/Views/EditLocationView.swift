import SwiftUI
import Kingfisher

/// Edit view for an existing location with all editable fields.
///
/// Phase 2a-3: form state, photo loading, and save pipeline live in
/// `EditLocationViewModel`. This view is now a thin Form layout.
struct EditLocationView: View {
    var onLocationUpdated: ((Location) -> Void)?

    @StateObject private var viewModel: EditLocationViewModel
    @Environment(\.dismiss) var dismiss

    // UI-only sheet/alert state
    @State private var showingSuccess = false
    @State private var showingDeletePhotoConfirmation = false
    @State private var photoToDeleteId: Int?

    init(location: Location, onLocationUpdated: ((Location) -> Void)? = nil) {
        self.onLocationUpdated = onLocationUpdated
        _viewModel = StateObject(wrappedValue: EditLocationViewModel(location: location))
    }

    private var location: Location { viewModel.location }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                productionDateSection
                productionDetailsSection
                notesSection
                tagsSection
                ratingSection
                photosSection
                locationInfoSection
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Location updated successfully!")
            }
            .alert("Delete Photo?", isPresented: $showingDeletePhotoConfirmation) {
                Button("Cancel", role: .cancel) {
                    photoToDeleteId = nil
                }
                Button("Mark for Deletion", role: .destructive) {
                    if let id = photoToDeleteId {
                        viewModel.markPhotoForDeletion(id)
                    }
                    photoToDeleteId = nil
                }
            } message: {
                Text("This photo will be permanently deleted when you save.")
            }
        }
        .task {
            await viewModel.loadPhotos()
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        Section {
            TextField("Location Name", text: $viewModel.locationName)
                .autocapitalization(.words)
                .fontWeight(.bold)
                .onChange(of: viewModel.locationName) { _, _ in viewModel.enforceLimits() }

            Picker("Type", selection: $viewModel.locationType) {
                ForEach(LocationTypeColors.standardTypes, id: \.self) { type in
                    HStack {
                        Image(systemName: LocationTypeColors.icon(for: type))
                        Text(type)
                    }
                    .tag(type)
                }
            }

            Toggle("Favorite", isOn: $viewModel.isFavorite)
                .tint(.yellow)
        } header: {
            Label("Basic Info", systemImage: "info.circle")
        }
    }

    private var productionDateSection: some View {
        Section {
            Toggle("Set Production Date", isOn: $viewModel.hasProductionDate)
                .tint(.blue)

            if viewModel.hasProductionDate {
                DatePicker(
                    "Date",
                    selection: $viewModel.productionDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
            }
        } header: {
            Label("Production Date", systemImage: "calendar")
        }
    }

    private var productionDetailsSection: some View {
        Section {
            TextField("Production Notes", text: $viewModel.productionNotes, axis: .vertical)
                .lineLimit(3...6)
                .onChange(of: viewModel.productionNotes) { _, _ in viewModel.enforceLimits() }

            TextField("Entry Point", text: $viewModel.entryPoint)
                .onChange(of: viewModel.entryPoint) { _, _ in viewModel.enforceLimits() }

            TextField("Parking", text: $viewModel.parking)
                .onChange(of: viewModel.parking) { _, _ in viewModel.enforceLimits() }

            TextField("Access", text: $viewModel.access)
                .onChange(of: viewModel.access) { _, _ in viewModel.enforceLimits() }

            Picker("Indoor/Outdoor", selection: $viewModel.indoorOutdoor) {
                Text("Not Set").tag("")
                Text("Indoor").tag("indoor")
                Text("Outdoor").tag("outdoor")
                Text("Both").tag("both")
            }

            Toggle("Permanent Location", isOn: $viewModel.isPermanent)
                .tint(.green)
        } header: {
            Label("Production Details", systemImage: "film")
        }
    }

    private var notesSection: some View {
        Section {
            TextField("Notes", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)
                .onChange(of: viewModel.notes) { _, _ in viewModel.enforceLimits() }

            TextField("Personal Caption", text: $viewModel.caption)
                .onChange(of: viewModel.caption) { _, _ in viewModel.enforceLimits() }
        } header: {
            Label("Notes", systemImage: "note.text")
        }
    }

    private var tagsSection: some View {
        Section {
            TextField("Tags (comma-separated)", text: $viewModel.tagsText)
                .autocapitalization(.none)

            if !viewModel.parsedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.parsedTags, id: \.self) { tag in
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
    }

    private var ratingSection: some View {
        Section {
            HStack {
                Text("Rating")
                Spacer()
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(viewModel.personalRating) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                viewModel.personalRating = Double(star)
                            }
                    }
                }
            }

            if viewModel.personalRating > 0 {
                Button("Clear Rating") {
                    viewModel.personalRating = 0
                }
                .foregroundColor(.destructive)
                .font(.caption)
            }
        } header: {
            Label("Personal Rating", systemImage: "star")
        }
    }

    private var photosSection: some View {
        Section {
            if viewModel.isLoadingPhotos {
                HStack {
                    Spacer()
                    ProgressView("Loading photos...")
                    Spacer()
                }
            } else if viewModel.photos.isEmpty {
                Text("No photos")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.photos) { photo in
                    photoRow(photo)
                }

                if !viewModel.photosToDelete.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.warning)
                        Text("\(viewModel.photosToDelete.count) photo(s) will be deleted on save")
                            .font(.caption)
                            .foregroundColor(.warning)
                    }

                    Button("Undo All Photo Deletions") {
                        viewModel.undoAllPhotoDeletions()
                    }
                    .font(.caption)
                }
            }
        } header: {
            Label("Photos (\(viewModel.photos.count - viewModel.photosToDelete.count))", systemImage: "photo.stack")
        }
    }

    @ViewBuilder
    private func photoRow(_ photo: DetailPhoto) -> some View {
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
                .onFailureView {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
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

            if viewModel.photosToDelete.contains(photo.id) {
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

    private var locationInfoSection: some View {
        Section {
            DetailRow(label: "Address", value: location.address ?? "N/A")
            DetailRow(label: "Latitude", value: String(format: "%.6f", location.latitude))
            DetailRow(label: "Longitude", value: String(format: "%.6f", location.longitude))
            DetailRow(label: "Place ID", value: location.placeId ?? "N/A")
        } header: {
            Label("Location Info (Read-Only)", systemImage: "mappin.and.ellipse")
        }
    }

    // MARK: - Actions

    private func save() async {
        if let updated = await viewModel.saveChanges() {
            onLocationUpdated?(updated)
            showingSuccess = true
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
