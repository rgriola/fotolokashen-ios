import SwiftUI
import MapKit

/// Compact map showing where each photo was taken relative to the location pin.
/// Displayed in LocationDetailView when ≥2 photos have distinct GPS coordinates.
struct PhotoSpreadMapView: View {
    let locationCoordinate: CLLocationCoordinate2D
    let photos: [DetailPhoto]

    /// Only photos that have valid GPS data
    private var geotaggedPhotos: [(index: Int, coordinate: CLLocationCoordinate2D)] {
        photos.enumerated().compactMap { index, photo in
            guard let lat = photo.gpsLatitude, let lng = photo.gpsLongitude,
                  lat != 0, lng != 0 else { return nil }
            return (index: index, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
    }

    /// True if there are ≥2 distinct GPS positions worth showing
    var hasSpread: Bool {
        let coords = geotaggedPhotos
        guard coords.count >= 2 else { return false }
        // Check that at least 2 positions are >10m apart
        let first = CLLocation(latitude: coords[0].coordinate.latitude,
                               longitude: coords[0].coordinate.longitude)
        return coords.dropFirst().contains { item in
            let loc = CLLocation(latitude: item.coordinate.latitude,
                                 longitude: item.coordinate.longitude)
            return first.distance(from: loc) > 10
        }
    }

    /// Human-readable span description
    private var spanDescription: String {
        let coords = geotaggedPhotos.map {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        guard coords.count >= 2 else { return "" }

        var maxDistance: CLLocationDistance = 0
        for i in 0..<coords.count {
            for j in (i+1)..<coords.count {
                let d = coords[i].distance(from: coords[j])
                if d > maxDistance { maxDistance = d }
            }
        }

        if maxDistance < 1000 {
            return String(format: "%.0f m", maxDistance)
        } else {
            let miles = maxDistance / 1609.344
            return String(format: "%.1f mi", miles)
        }
    }

    /// Region that fits all pins with padding
    private var mapRegion: MKCoordinateRegion {
        var allCoords = geotaggedPhotos.map(\.coordinate)
        allCoords.append(locationCoordinate)

        let lats = allCoords.map(\.latitude)
        let lngs = allCoords.map(\.longitude)

        let minLat = lats.min() ?? locationCoordinate.latitude
        let maxLat = lats.max() ?? locationCoordinate.latitude
        let minLng = lngs.min() ?? locationCoordinate.longitude
        let maxLng = lngs.max() ?? locationCoordinate.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        // Add 40% padding so pins aren't at the edges
        let latDelta = max((maxLat - minLat) * 1.4, 0.002)
        let lngDelta = max((maxLng - minLng) * 1.4, 0.002)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header (tappable to collapse)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.caption)
                        .foregroundColor(.brand)
                    Text("Photo Locations (\(geotaggedPhotos.count) with GPS)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Map with pins
                Map(initialPosition: .region(mapRegion)) {
                    // Location pin (primary — red)
                    Annotation("Location", coordinate: locationCoordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                            )
                    }

                    // Photo pins (secondary — blue)
                    ForEach(geotaggedPhotos, id: \.index) { item in
                        Annotation("Photo \(item.index + 1)", coordinate: item.coordinate) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1.5)
                                )
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Span label
                HStack {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Span: \(spanDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
