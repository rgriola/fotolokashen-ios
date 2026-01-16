import SwiftUI
import CoreLocation

/// Form for creating a new location with captured photo
struct CreateLocationView: View {
    
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) var dismiss
    
    let photo: UIImage
    let photoLocation: CLLocation?
    var onLocationCreated: ((Location) -> Void)?
    
    @State private var locationName = ""
    @State private var locationType = "Exterior"
    @State private var address = "Loading address..."
    @State private var isLoadingAddress = true
    @State private var showingSuccess = false
    @State private var createdLocation: Location?
    
    // Location types (matching backend)
    private let locationTypes = [
        "Exterior",
        "Interior",
        "Studio",
        "Park",
        "Beach",
        "Urban",
        "Rural",
        "Commercial",
        "Residential",
        "Industrial",
        "Natural",
        "Historic",
        "Modern",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo preview
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    
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
                        
                        Divider()
                        
                        // GPS Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("GPS Information")
                                .font(.headline)
                            
                            if let location = photoLocation {
                                // Address
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.blue)
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
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                
                                // Coordinates
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.green)
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
                                .background(Color.gray.opacity(0.1))
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
                                    .background(Color.yellow.opacity(0.1))
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
                            if locationService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Creating...")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Create Location")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || locationService.isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    // Error message
                    if let error = locationService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
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
            await loadAddress()
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
        !locationName.isEmpty && photoLocation != nil
    }
    
    // MARK: - Methods
    
    private func loadAddress() async {
        guard let location = photoLocation else {
            address = "No GPS data"
            isLoadingAddress = false
            return
        }
        
        do {
            address = try await locationService.getAddress(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            isLoadingAddress = false
        } catch {
            address = "Address unavailable"
            isLoadingAddress = false
        }
    }
    
    private func saveLocation() async {
        guard let location = photoLocation else { return }
        
        // Ensure we have a valid address - use coordinates as fallback
        let finalAddress: String
        if address == "Loading address..." || address == "Address unavailable" || address == "No GPS data" {
            // Use coordinates as fallback address
            finalAddress = String(format: "%.6f, %.6f", 
                                location.coordinate.latitude,
                                location.coordinate.longitude)
        } else {
            finalAddress = address
        }
        
        do {
            let createdLoc = try await locationService.createLocation(
                name: locationName,
                type: locationType,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                address: finalAddress,
                photo: photo,
                photoLocation: location
            )
            
            createdLocation = createdLoc
            showingSuccess = true
            
        } catch {
            // Error is already set in locationService.errorMessage
        }
    }
}

// MARK: - Preview

#Preview {
    CreateLocationView(
        photo: UIImage(systemName: "photo")!,
        photoLocation: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
}
