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
                        
                        // Production Date (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Production Date")
                                .font(.headline)
                            
                            Toggle("Set Production Date", isOn: $hasProductionDate)
                                .tint(.blue)
                                .onChange(of: hasProductionDate) { newValue in
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
        print("📍 [CreateLocationView.loadAddress] ========== START ==========")
        guard let location = photoLocation else {
            print("❌ [CreateLocationView.loadAddress] No photoLocation available!")
            address = "No GPS data"
            isLoadingAddress = false
            return
        }
        
        print("📍 [CreateLocationView.loadAddress] Photo location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        do {
            // Get full geocoded address data including placeId, street, city, state, zipcode
            print("📍 [CreateLocationView.loadAddress] Calling getGeocodedAddress...")
            let geocoded = try await locationService.getGeocodedAddress(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            geocodedAddressData = geocoded
            address = geocoded.formattedAddress
            isLoadingAddress = false
            
            print("✅ [CreateLocationView.loadAddress] Geocoding successful!")
            print("   placeId: \(geocoded.placeId)")
            print("   formattedAddress: \(geocoded.formattedAddress)")
            print("   fullStreet: \(geocoded.fullStreet ?? "nil")")
            print("   city: \(geocoded.city ?? "nil")")
            print("   state: \(geocoded.state ?? "nil")")
            print("   zipcode: \(geocoded.zipcode ?? "nil")")
            print("📍 [CreateLocationView.loadAddress] ========== END ==========")
        } catch {
            print("❌ [CreateLocationView.loadAddress] Geocoding FAILED!")
            print("   Error: \(error)")
            print("   Error description: \(error.localizedDescription)")
            address = "Address unavailable"
            isLoadingAddress = false
        }
    }
    
    private func saveLocation() async {
        print("💾 [CreateLocationView.saveLocation] ========== START ==========")
        guard let location = photoLocation else {
            print("❌ [CreateLocationView.saveLocation] No photoLocation!")
            return
        }
        
        print("💾 [CreateLocationView.saveLocation] Location name: \(locationName)")
        print("💾 [CreateLocationView.saveLocation] Location type: \(locationType)")
        print("💾 [CreateLocationView.saveLocation] Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("💾 [CreateLocationView.saveLocation] Has geocodedAddressData: \(geocodedAddressData != nil)")
        
        // Create fallback geocoded address using coordinates if geocoding failed
        let geocodedAddress: GeocodedAddress
        if let existingGeocodedData = geocodedAddressData {
            print("✅ [CreateLocationView.saveLocation] Using existing geocoded data")
            geocodedAddress = existingGeocodedData
        } else {
            // Create fallback with coordinates as address and a generated placeId
            print("⚠️ [CreateLocationView.saveLocation] WARNING: Creating fallback geocoded address!")
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
            print("⚠️ [CreateLocationView.saveLocation] Fallback placeId: \(geocodedAddress.placeId)")
            print("⚠️ [CreateLocationView.saveLocation] Fallback address: \(geocodedAddress.formattedAddress)")
        }
        
        print("💾 [CreateLocationView.saveLocation] Calling locationService.createLocation...")
        
        do {
            let createdLoc = try await locationService.createLocation(
                name: locationName,
                type: locationType,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                geocodedAddress: geocodedAddress,
                photo: photo,
                photoLocation: location,
                productionDate: productionDate  // Pass production date
            )
            
            print("✅ [CreateLocationView.saveLocation] Location created successfully!")
            print("   Location ID: \(createdLoc.id)")
            print("   Location name: \(createdLoc.name)")
            print("💾 [CreateLocationView.saveLocation] ========== END ==========")
            
            createdLocation = createdLoc
            showingSuccess = true
            
        } catch {
            print("❌ [CreateLocationView.saveLocation] FAILED!")
            print("   Error: \(error)")
            print("   Error description: \(error.localizedDescription)")
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
