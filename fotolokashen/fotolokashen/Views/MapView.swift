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
    @State private var selectedReadOnlyContext: ReadOnlyLocationContext?
    @State private var centerOnUserLocation = false
    @State private var focusCoordinate: CLLocationCoordinate2D? = nil
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
                    centerOnUserLocation: $centerOnUserLocation,
                    focusCoordinate: $focusCoordinate,
                    onMarkerTap: { location in
                        selectedLocation = location
                    },
                    onSocialMarkerTap: { socialLocation in
                        // Convert MapSocialLocation to ReadOnlyLocationContext for full detail view
                        let context = createReadOnlyContext(from: socialLocation)
                        selectedReadOnlyContext = context
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
                            #if DEBUG
                            print("[MapView] Friends toggle: \(showFriendsLocations), cached: \(friendsLocations.count)")
                            #endif
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
                            .background(showFriendsLocations ? Color.brandPurple : Color(.systemGray2))
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
                                .background(Color.brand)
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
            .sheet(item: $selectedReadOnlyContext) { context in
                LocationDetailView(readOnlyContext: context)
            }
        }
        .task {
            await locationStore.fetchLocations()
        }
        .onChange(of: locationStore.mapFocusLocation) { _, location in
            if let loc = location {
                selectedLocation = loc
                focusCoordinate = CLLocationCoordinate2D(
                    latitude: loc.latitude,
                    longitude: loc.longitude
                )
                locationStore.mapFocusLocation = nil
            }
        }
        .onChange(of: locationStore.mapFocusReadOnlyContext) { _, context in
            if let ctx = context {
                selectedReadOnlyContext = ctx
                focusCoordinate = CLLocationCoordinate2D(
                    latitude: ctx.location.latitude,
                    longitude: ctx.location.longitude
                )
                locationStore.mapFocusReadOnlyContext = nil
            }
        }
    }

    private func loadFriendsLocations() async {
        #if DEBUG
        print("[MapView] loadFriendsLocations() called")
        #endif
        isLoadingFriends = true
        do {
            friendsLocations = try await followService.getFriendsLocations()
            #if DEBUG
            print("[MapView] Loaded \(friendsLocations.count) friends locations")
            #endif
        } catch {
            #if DEBUG
            print("[MapView] Failed to load friends locations: \(error)")
            #endif
        }
        isLoadingFriends = false
    }

    /// Convert MapSocialLocation to ReadOnlyLocationContext for displaying full LocationDetailView
    private func createReadOnlyContext(from socialLocation: MapSocialLocation) -> ReadOnlyLocationContext {
        // Synthesize a Location from MapSocialLocation
        let location = Location(
            id: socialLocation.id,
            name: socialLocation.name,
            address: socialLocation.address ?? "",
            latitude: socialLocation.lat,
            longitude: socialLocation.lng,
            type: socialLocation.type ?? "OTHER",
            placeId: socialLocation.placeId ?? "",
            createdAt: socialLocation.savedAt ?? "",
            photosCount: 0,  // Photos will be fetched by LocationDetailView
            thumbnailUrl: nil,
            userSaveId: nil,
            city: socialLocation.city,
            state: socialLocation.state,
            caption: socialLocation.caption
        )

        return ReadOnlyLocationContext(
            id: socialLocation.id,
            location: location,
            ownerUsername: socialLocation.user?.username ?? "",
            ownerDisplayName: socialLocation.user?.displayName ?? "",
            photos: []  // Photos will be fetched by LocationDetailView via fetchPhotosFromPublicProfile
        )
    }
}

// MARK: - Clustered Map View

struct ClusteredMapView: UIViewRepresentable {
    let locations: [Location]
    let socialLocations: [MapSocialLocation]
    @Binding var selectedLocation: Location?
    @Binding var centerOnUserLocation: Bool
    @Binding var focusCoordinate: CLLocationCoordinate2D?
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
        
        context.coordinator.gmsMapView = mapView
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        #if DEBUG
        print("[MapView] updateUIView: \(locations.count) locations, \(socialLocations.count) social locations")
        #endif
        
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

        // Handle focus on a specific location (e.g. from address tap)
        if let coordinate = focusCoordinate {
            let camera = GMSCameraPosition.camera(
                withLatitude: coordinate.latitude,
                longitude: coordinate.longitude,
                zoom: 15.0
            )
            mapView.animate(to: camera)
            DispatchQueue.main.async {
                self.focusCoordinate = nil
            }
        }
        
        // Clear existing markers
        context.coordinator.markers.forEach { $0.map = nil }
        context.coordinator.markers.removeAll()
        
        // Add markers directly to map at exact GPS locations (no clustering)
        var bounds = GMSCoordinateBounds()
        
        // Add location markers
        for location in locations {
            let position = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            let marker = GMSMarker(position: position)
            marker.icon = MarkerIconGenerator.cameraMarker(for: location.type ?? "")
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            marker.title = location.name
            marker.userData = location
            marker.map = mapView
            
            context.coordinator.markers.append(marker)
            bounds = bounds.includingCoordinate(position)
        }

        // Add social location markers (friends' locations - camera icon with type color)
        for socialLocation in socialLocations {
            let position = CLLocationCoordinate2D(
                latitude: socialLocation.latitude,
                longitude: socialLocation.longitude
            )
            
            let marker = GMSMarker(position: position)
            marker.icon = MarkerIconGenerator.cameraMarker(for: socialLocation.type ?? "")
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            marker.title = socialLocation.name
            marker.userData = socialLocation
            marker.map = mapView
            
            context.coordinator.markers.append(marker)
            bounds = bounds.includingCoordinate(position)
        }
        
        // Only auto-fit on first load
        if !locations.isEmpty && !context.coordinator.hasPerformedInitialFit {
            let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
            mapView.animate(with: update)
            
            // Limit maximum zoom to 18
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if mapView.camera.zoom > 18.0 {
                    let limitUpdate = GMSCameraUpdate.zoom(to: 18.0)
                    mapView.animate(with: limitUpdate)
                }
            }
            
            context.coordinator.hasPerformedInitialFit = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: ClusteredMapView
        var hasPerformedInitialFit = false
        var gmsMapView: GMSMapView?
        var markers: [GMSMarker] = []
        
        init(_ parent: ClusteredMapView) {
            self.parent = parent
        }
        
        // Handle marker tap
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            // Check if it's a location marker
            if let location = marker.userData as? Location {
                parent.selectedLocation = location
                parent.onMarkerTap(location)
                return true
            }
            
            // Check if it's a social location marker
            if let socialLocation = marker.userData as? MapSocialLocation {
                parent.onSocialMarkerTap(socialLocation)
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


