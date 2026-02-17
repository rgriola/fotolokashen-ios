import SwiftUI
import GoogleMaps
import GoogleMapsUtils
import CoreLocation
import Combine

/// Map view showing all user locations as markers with clustering
/// Supports toggling friends' locations (purple markers) on the map
struct MapView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var locationStore = LocationStore.shared
    @ObservedObject private var followService = FollowService.shared
    @State private var selectedLocation: Location?
    @State private var selectedSocialLocation: MapSocialLocation?
    @State private var centerOnUserLocation = false
    @State private var showFriendsLocations = false
    @State private var friendsLocations: [MapSocialLocation] = []
    @State private var isLoadingFriends = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Google Map with clustering
                ClusteredMapView(
                    locations: locationStore.locations,
                    socialLocations: showFriendsLocations ? friendsLocations : [],
                    selectedLocation: $selectedLocation,
                    selectedSocialLocation: $selectedSocialLocation,
                    centerOnUserLocation: $centerOnUserLocation,
                    onMarkerTap: { location in
                        selectedLocation = location
                    },
                    onSocialMarkerTap: { socialLocation in
                        selectedSocialLocation = socialLocation
                    }
                )
                .ignoresSafeArea()
                
                // Bottom buttons
                VStack {
                    Spacer()
                    HStack {
                        // Friends toggle button
                        Button {
                            showFriendsLocations.toggle()
                            if showFriendsLocations && friendsLocations.isEmpty {
                                Task { await loadFriendsLocations() }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isLoadingFriends {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: showFriendsLocations ? "person.2.fill" : "person.2")
                                }
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(showFriendsLocations ? Color.brandPurple : Color.gray.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        }
                        .padding(.leading)

                        Spacer()

                        // Current location button
                        Button {
                            centerOnUserLocation = true
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
            .sheet(item: $selectedLocation) { location in
                LocationDetailView(location: location)
            }
            .sheet(item: $selectedSocialLocation) { socialLocation in
                SocialLocationDetailSheet(socialLocation: socialLocation)
            }
        }
        .task {
            await locationStore.fetchLocations()
        }
    }

    private func loadFriendsLocations() async {
        isLoadingFriends = true
        do {
            friendsLocations = try await followService.getFriendsLocations()
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[MapView] Failed to load friends locations: \(error)")
            }
            #endif
        }
        isLoadingFriends = false
    }
}

// MARK: - Clustered Map View

struct ClusteredMapView: UIViewRepresentable {
    let locations: [Location]
    let socialLocations: [MapSocialLocation]
    @Binding var selectedLocation: Location?
    @Binding var selectedSocialLocation: MapSocialLocation?
    @Binding var centerOnUserLocation: Bool
    let onMarkerTap: (Location) -> Void
    let onSocialMarkerTap: (MapSocialLocation) -> Void
    
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
        
        // Handle center on user location request
        if centerOnUserLocation {
            if let userLocation = mapView.myLocation {
                let camera = GMSCameraPosition.camera(
                    withLatitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude,
                    zoom: 15.0
                )
                mapView.animate(to: camera)
                print("[MapView] Centered on user location: \(userLocation.coordinate)")
            } else {
                print("[MapView] User location not available yet")
            }
            // Reset the flag
            DispatchQueue.main.async {
                self.centerOnUserLocation = false
            }
        }
        
        guard let clusterManager = context.coordinator.clusterManager else {
            print("[MapView] No cluster manager")
            return
        }
        
        // Clear existing items
        clusterManager.clearItems()
        context.coordinator.locationItems.removeAll()
        
        // Add location items to cluster manager
        var bounds = GMSCoordinateBounds()
        
        for location in locations {
            print("[MapView] Adding marker for: \(location.name) at \(location.latitude), \(location.longitude)")
            
            let item = LocationClusterItem(location: location)
            clusterManager.add(item)
            context.coordinator.locationItems.append(item)
            bounds = bounds.includingCoordinate(item.position)
        }

        // Add social location items (friends' locations)
        for socialLocation in socialLocations {
            let item = SocialLocationClusterItem(socialLocation: socialLocation)
            clusterManager.add(item)
            bounds = bounds.includingCoordinate(item.position)
        }
        
        // Cluster the items
        clusterManager.cluster()
        
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
        var locationItems: [LocationClusterItem] = []
        
        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }
        
        // Handle marker tap
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            // Check if it's a cluster item (set by LocationClusterRenderer)
            if let clusterItem = marker.userData as? LocationClusterItem {
                parent.selectedLocation = clusterItem.location
                parent.onMarkerTap(clusterItem.location)
                return true
            }
            
            // Check if it's a social location marker
            if let socialItem = marker.userData as? SocialLocationClusterItem {
                parent.selectedSocialLocation = socialItem.socialLocation
                parent.onSocialMarkerTap(socialItem.socialLocation)
                return true
            }

            // Check if it's already converted to a Location
            if let location = marker.userData as? Location {
                parent.selectedLocation = location
                parent.onMarkerTap(location)
                return true
            }
            
            // If it's a cluster, let the cluster manager handle it (return false)
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
        
        // GMUClusterManagerDelegate - called when individual cluster item is tapped
        func clusterManager(_ manager: GMUClusterManager, didTap clusterItem: GMUClusterItem) -> Bool {
            if let locationItem = clusterItem as? LocationClusterItem {
                parent.selectedLocation = locationItem.location
                parent.onMarkerTap(locationItem.location)
                return true
            }
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    MapView()
}

// MARK: - Social Location Detail Sheet

/// Sheet shown when tapping a friend's location marker on the map
struct SocialLocationDetailSheet: View {
    let socialLocation: MapSocialLocation
    @Environment(\.dismiss) private var dismiss
    @State private var showUserProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Location name and type
                    VStack(alignment: .leading, spacing: 4) {
                        Text(socialLocation.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let type = socialLocation.type {
                            HStack(spacing: 4) {
                                Image(systemName: LocationTypeColors.icon(for: type))
                                    .font(.caption)
                                Text(type)
                                    .font(.caption)
                            }
                            .foregroundColor(Color(LocationTypeColors.uiColor(for: type)))
                        }
                    }

                    // Address
                    if let address = socialLocation.address {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // City/State
                    if let city = socialLocation.city ?? socialLocation.state {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Caption
                    if let caption = socialLocation.caption, !caption.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Caption")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(caption)
                                .font(.body)
                        }
                    }

                    Divider()

                    // Saved by user
                    if let user = socialLocation.user {
                        Button {
                            showUserProfile = true
                        } label: {
                            HStack(spacing: 12) {
                                if let avatarURL = user.avatarURL {
                                    AsyncImage(url: avatarURL) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.brandPurple.opacity(0.2))
                                            .overlay(
                                                Text(String(user.username.prefix(1)).uppercased())
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.brandPurple)
                                            )
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.brandPurple.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(String(user.username.prefix(1)).uppercased())
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.brandPurple)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Saved by")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(user.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUserProfile) {
                if let user = socialLocation.user {
                    NavigationStack {
                        PublicProfileView(username: user.username)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showUserProfile = false }
                                }
                            }
                    }
                }
            }
        }
    }
}
