import SwiftUI
import GoogleMaps
import CoreLocation
import Combine

/// Map view showing all user locations as markers
struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedLocation: Location?
    @State private var showingLocationDetail = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Google Map
                GoogleMapView(
                    locations: viewModel.locations,
                    selectedLocation: $selectedLocation,
                    onMarkerTap: { location in
                        selectedLocation = location
                        showingLocationDetail = true
                    }
                )
                .ignoresSafeArea()
                
                // Current location button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            viewModel.centerOnCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLocationDetail) {
                if let location = selectedLocation {
                    LocationDetailView(location: location)
                }
            }
            .task {
                await viewModel.fetchLocations()
            }
        }
    }
}

// MARK: - Google Map View

struct GoogleMapView: UIViewRepresentable {
    let locations: [Location]
    @Binding var selectedLocation: Location?
    let onMarkerTap: (Location) -> Void
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: 40.7128,
            longitude: -74.0060,
            zoom: 12.0
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = false // We have custom button
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Clear existing markers
        mapView.clear()
        
        // Add markers for all locations
        var bounds = GMSCoordinateBounds()
        
        for location in locations {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            marker.title = location.name
            marker.snippet = location.address
            marker.userData = location
            
            // Custom marker icon based on type
            marker.icon = markerIcon(for: location.type ?? "")
            
            marker.map = mapView
            bounds = bounds.includingCoordinate(marker.position)
        }
        
        // Fit map to show all markers
        if locations.count > 0 {
            let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
            mapView.animate(with: update)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Marker Icons
    
    private func markerIcon(for type: String) -> UIImage {
        let color: UIColor
        
        switch type.uppercased() {
        case "BROLL":
            color = .systemBlue
        case "STORY":
            color = .systemPurple
        case "INTERVIEW":
            color = .systemOrange
        case "ESTABLISHING":
            color = .systemGreen
        case "DETAIL":
            color = .systemPink
        case "WIDE":
            color = .systemCyan
        case "MEDIUM":
            color = .systemIndigo
        case "CLOSE":
            color = .systemRed
        default:
            color = .systemGray
        }
        
        return GMSMarker.markerImage(with: color)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let location = marker.userData as? Location {
                parent.selectedLocation = location
                parent.onMarkerTap(location)
            }
            return true
        }
    }
}

// MARK: - View Model

@MainActor
class MapViewModel: ObservableObject {
    @Published var locations: [Location] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let locationService = LocationService.shared
    private let config = ConfigLoader.shared
    
    func fetchLocations() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if config.enableDebugLogging {
                print("[MapView] Fetching locations...")
            }
            
            locations = try await locationService.fetchLocations()
            
            if config.enableDebugLogging {
                print("[MapView] Fetched \(locations.count) locations")
            }
        } catch {
            if config.enableDebugLogging {
                print("[MapView] Error fetching locations: \(error)")
            }
            errorMessage = error.localizedDescription
        }
    }
    
    func centerOnCurrentLocation() {
        // This will be implemented with LocationManager
        if config.enableDebugLogging {
            print("[MapView] Centering on current location")
        }
    }
}

// MARK: - Preview

#Preview {
    MapView()
}
