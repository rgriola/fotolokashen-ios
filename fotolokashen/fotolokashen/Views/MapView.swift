import SwiftUI
import GoogleMaps
import GoogleMapsUtils
import CoreLocation
import Combine

/// Map view showing all user locations as markers with clustering
struct MapView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var locationStore = LocationStore.shared
    @State private var selectedLocation: Location?
    @State private var showingLocationDetail = false
    @State private var showingCamera = false
    @State private var showingLogoutConfirmation = false
    @State private var capturedPhoto: PhotoCapture?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Google Map with clustering
                ClusteredMapView(
                    locations: locationStore.locations,
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
                            // TODO: Implement center on current location
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image, location in
                    capturedPhoto = PhotoCapture(image: image, location: location)
                }
            }
            .sheet(item: $capturedPhoto) { capture in
                CreateLocationView(
                    photo: capture.image,
                    photoLocation: capture.location
                ) { location in
                    // Location created - add to shared store
                    locationStore.addLocation(location)
                }
            }
            .sheet(isPresented: $showingLocationDetail) {
                if let location = selectedLocation {
                    LocationDetailView(location: location)
                }
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    Task {
                        locationStore.clear()
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
        .task {
            await locationStore.fetchLocations()
        }
    }
}

// MARK: - Clustered Map View

struct ClusteredMapView: UIViewRepresentable {
    let locations: [Location]
    @Binding var selectedLocation: Location?
    let onMarkerTap: (Location) -> Void
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: 40.7128,
            longitude: -74.0060,
            zoom: 15.0
        )
        let mapView = GMSMapView()
        mapView.camera = camera
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        
        // Setup clustering with custom colors
        let iconGenerator = GMUDefaultClusterIconGenerator(
            buckets: [10, 50, 100, 200, 1000],
            backgroundColors: [
                UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.9),  // Light blue (< 10)
                UIColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 0.9),  // Blue (10-49)
                UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 0.9),  // Purple (50-99)
                UIColor(red: 0.8, green: 0.2, blue: 0.6, alpha: 0.9),  // Pink (100-199)
                UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.9)   // Red (200+)
            ]
        )
        let algorithm = GMUNonHierarchicalDistanceBasedAlgorithm()
        let renderer = LocationClusterRenderer(
            mapView: mapView,
            clusterIconGenerator: iconGenerator
        )
        
        let clusterManager = GMUClusterManager(
            map: mapView,
            algorithm: algorithm,
            renderer: renderer
        )
        clusterManager.setDelegate(context.coordinator, mapDelegate: context.coordinator)
        
        context.coordinator.clusterManager = clusterManager
        context.coordinator.gmsMapView = mapView
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        print("[MapView] updateUIView called with \(locations.count) locations")
        
        guard let clusterManager = context.coordinator.clusterManager else {
            print("[MapView] No cluster manager")
            return
        }
        
        // Clear existing items
        clusterManager.clearItems()
        
        // Add location items to cluster manager
        var bounds = GMSCoordinateBounds()
        
        for location in locations {
            print("[MapView] Adding marker for: \(location.name) at \(location.latitude), \(location.longitude)")
            
            let item = LocationClusterItem(location: location)
            clusterManager.add(item)
            bounds = bounds.includingCoordinate(item.position)
        }
        
        // Cluster the items
        clusterManager.cluster()
        
        // Customize markers after clustering
        context.coordinator.customizeMarkers(in: mapView)
        
        // Only auto-fit on first load
        if !locations.isEmpty && !context.coordinator.hasPerformedInitialFit {
            print("[MapView] Performing initial fit to show all \(locations.count) markers")
            let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
            mapView.animate(with: update)
            
            // Limit maximum zoom to 18
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if mapView.camera.zoom > 18.0 {
                    print("[MapView] Zoom too high (\(mapView.camera.zoom)), limiting to 18.0")
                    let limitUpdate = GMSCameraUpdate.zoom(to: 18.0)
                    mapView.animate(with: limitUpdate)
                }
            }
            
            context.coordinator.hasPerformedInitialFit = true
        } else if !locations.isEmpty {
            print("[MapView] Markers updated, keeping user's zoom level")
        } else {
            print("[MapView] No locations to display")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, GMSMapViewDelegate, GMUClusterManagerDelegate {
        var parent: ClusteredMapView
        var hasPerformedInitialFit = false
        var clusterManager: GMUClusterManager?
        var gmsMapView: GMSMapView?
        
        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }
        
        // Handle marker tap
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            // Check if it's a location marker (not a cluster)
            if let location = marker.userData as? Location {
                // Customize marker icon on tap
                marker.icon = markerIcon(for: location.type ?? "")
                marker.title = location.name
                marker.snippet = location.address
                
                parent.selectedLocation = location
                parent.onMarkerTap(location)
                return true
            }
            
            // If it's a cluster, let the cluster manager handle it
            return false
        }
        
        // GMUClusterManagerDelegate - called when cluster is tapped
        func clusterManager(_ manager: GMUClusterManager, didTap cluster: GMUCluster) -> Bool {
            // Zoom into cluster using stored map view reference
            guard let gmsMapView = self.gmsMapView else {
                return false
            }
            
            let newCamera = GMSCameraPosition.camera(
                withTarget: cluster.position,
                zoom: gmsMapView.camera.zoom + 2
            )
            gmsMapView.animate(to: newCamera)
            return true
        }
        
        // Customize all visible markers after clustering
        func customizeMarkers(in mapView: GMSMapView) {
            // Markers will be customized when tapped or info window is shown
        }
        
        // Helper to create colored marker icons
        func markerIcon(for type: String) -> UIImage {
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
    }
}

// MARK: - Preview

#Preview {
    MapView()
}
