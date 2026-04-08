import Foundation
import CoreLocation

// MARK: - Geocoding Service

/// Handles reverse geocoding using Google Maps API with Apple CLGeocoder fallback.
/// Extracted from LocationService for single-responsibility.
class GeocodingService {

    // MARK: - Singleton

    static let shared = GeocodingService()

    private let config = ConfigLoader.shared

    // MARK: - Public Methods

    /// Get address from coordinates using Google Maps Geocoding API
    /// Returns just the formatted address string (legacy method)
    func getAddress(latitude: Double, longitude: Double) async throws -> String {
        #if DEBUG
        if config.enableDebugLogging {
            print("[GeocodingService] getAddress called with lat: \(latitude), lng: \(longitude)")
        }
        #endif
        let geocodedAddress = try await getGeocodedAddress(latitude: latitude, longitude: longitude)
        return geocodedAddress.formattedAddress
    }

    /// Get full geocoded address data from coordinates
    /// Tries Google Maps Geocoding API first, falls back to Apple CLGeocoder
    func getGeocodedAddress(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        #if DEBUG
        if config.enableDebugLogging {
            print("[GeocodingService] getGeocodedAddress for: \(latitude), \(longitude)")
        }
        #endif

        // Try Google Maps first
        do {
            let result = try await getGeocodedAddressFromGoogle(latitude: latitude, longitude: longitude)
            #if DEBUG
            if config.enableDebugLogging {
                print("[GeocodingService] Google Maps geocoding succeeded")
            }
            #endif
            return result
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[GeocodingService] Google Maps failed: \(error), falling back to Apple CLGeocoder")
            }
            #endif
        }

        // Fallback to Apple's CLGeocoder (no API key needed)
        return try await getGeocodedAddressFromApple(latitude: latitude, longitude: longitude)
    }

    // MARK: - Google Maps Geocoding

    private func getGeocodedAddressFromGoogle(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        let apiKey = config.googleMapsAPIKey
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(latitude),\(longitude)&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw GeocodingError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeocodingError.geocodingFailed
        }

        let geocodeResponse: GeocodeResponse
        do {
            geocodeResponse = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[GeocodingService] JSON decode error: \(error)")
            }
            #endif
            throw error
        }

        if geocodeResponse.status != "OK" {
            throw GeocodingError.geocodingFailed
        }

        guard let firstResult = geocodeResponse.results.first else {
            throw GeocodingError.noResults
        }

        // Extract address components
        var streetNumber: String?
        var street: String?
        var city: String?
        var state: String?
        var zipcode: String?

        for component in firstResult.addressComponents {
            let types = component.types

            if types.contains("street_number") {
                streetNumber = component.longName
            } else if types.contains("route") {
                street = component.longName
            } else if types.contains("locality") {
                city = component.longName
            } else if types.contains("administrative_area_level_1") {
                state = component.shortName
            } else if types.contains("postal_code") {
                zipcode = component.longName
            }
        }

        let geocodedAddress = GeocodedAddress(
            placeId: firstResult.placeId,
            formattedAddress: firstResult.formattedAddress,
            streetNumber: streetNumber,
            street: street,
            city: city,
            state: state,
            zipcode: zipcode
        )

        #if DEBUG
        if config.enableDebugLogging {
            print("[GeocodingService] Google result: \(geocodedAddress.formattedAddress)")
            print("  placeId: \(geocodedAddress.placeId)")
            print("  fullStreet: \(geocodedAddress.fullStreet ?? "nil")")
            print("  city: \(geocodedAddress.city ?? "nil"), state: \(geocodedAddress.state ?? "nil")")
        }
        #endif

        return geocodedAddress
    }

    // MARK: - Apple CLGeocoder Fallback

    private func getGeocodedAddressFromApple(latitude: Double, longitude: Double) async throws -> GeocodedAddress {
        #if DEBUG
        if config.enableDebugLogging {
            print("[GeocodingService] Apple CLGeocoder starting...")
        }
        #endif

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)

        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.reverseGeocodeLocation(location)
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[GeocodingService] Apple geocoding failed: \(error)")
            }
            #endif
            throw GeocodingError.geocodingFailed
        }

        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }

        // Build formatted address
        var addressParts: [String] = []

        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            addressParts.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            addressParts.append(thoroughfare)
        } else if let name = placemark.name {
            addressParts.append(name)
        }

        if let city = placemark.locality {
            addressParts.append(city)
        }

        if let state = placemark.administrativeArea {
            addressParts.append(state)
        }

        if let zipcode = placemark.postalCode {
            addressParts.append(zipcode)
        }

        let formattedAddress = addressParts.joined(separator: ", ")

        // Generate a unique placeId since Apple doesn't provide Google Place IDs
        let applePlaceId = "apple-\(latitude)-\(longitude)-\(Date().timeIntervalSince1970)"

        let geocodedAddress = GeocodedAddress(
            placeId: applePlaceId,
            formattedAddress: formattedAddress,
            streetNumber: placemark.subThoroughfare,
            street: placemark.thoroughfare,
            city: placemark.locality,
            state: placemark.administrativeArea,
            zipcode: placemark.postalCode
        )

        #if DEBUG
        if config.enableDebugLogging {
            print("[GeocodingService] Apple result: \(geocodedAddress.formattedAddress)")
            print("  placeId: \(geocodedAddress.placeId)")
            print("  fullStreet: \(geocodedAddress.fullStreet ?? "nil")")
            print("  city: \(geocodedAddress.city ?? "nil"), state: \(geocodedAddress.state ?? "nil")")
        }
        #endif

        return geocodedAddress
    }
}

// MARK: - Geocoding Models

struct GeocodeResponse: Codable {
    let results: [GeocodeResult]
    let status: String
}

struct GeocodeResult: Codable {
    let placeId: String
    let formattedAddress: String
    let addressComponents: [AddressComponent]

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case formattedAddress = "formatted_address"
        case addressComponents = "address_components"
    }
}

struct AddressComponent: Codable {
    let longName: String
    let shortName: String
    let types: [String]

    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case shortName = "short_name"
        case types
    }
}

/// Structured geocoding data extracted from Google Geocoding API
struct GeocodedAddress {
    let placeId: String
    let formattedAddress: String
    let streetNumber: String?
    let street: String?
    let city: String?
    let state: String?
    let zipcode: String?

    /// Combines street number and street name into a full street address
    var fullStreet: String? {
        if let number = streetNumber, let route = street {
            return "\(number) \(route)"
        }
        return street
    }
}

// MARK: - Errors

enum GeocodingError: Error, LocalizedError {
    case invalidURL
    case geocodingFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid geocoding URL"
        case .geocodingFailed:
            return "Failed to get address from coordinates"
        case .noResults:
            return "No address found for these coordinates"
        }
    }
}
