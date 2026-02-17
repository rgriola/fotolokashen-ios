import Foundation
import UIKit
import CoreLocation
import Combine

/// Service for secure photo uploads via server-mediated endpoint
/// All uploads go through /api/photos/upload for virus scanning,
/// format validation, and compression before reaching CDN
@MainActor
class PhotoUploadService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    private let apiClient = APIClient.shared
    private let imageCompressor = ImageCompressor()
    private let config = ConfigLoader.shared
    
    // MARK: - Upload Photo
    
    /// Upload photo to a location via secure server endpoint
    /// Server performs: virus scanning, format validation, HEIC/TIFF conversion, compression
    func uploadPhoto(
        image: UIImage,
        locationId: Int,
        location: CLLocation?,
        caption: String? = nil
    ) async throws -> Photo {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        do {
            // Step 1: Compress image locally (reduces upload time)
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] Compressing image locally...")
            }
            #endif
            
            guard let compressedData = ImageCompressor.compress(image) else {
                throw PhotoUploadError.compressionFailed
            }
            
            uploadProgress = 0.2
            
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] Compressed to \(compressedData.count / 1024)KB")
            }
            #endif
            
            // Step 2: Build metadata for GPS/EXIF data
            let metadata = buildUploadMetadata(location: location)
            
            uploadProgress = 0.3
            
            // Step 3: Upload via secure server endpoint
            // Server performs: virus scan, format validation, additional compression
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] Uploading via secure endpoint...")
            }
            #endif
            
            let secureResponse = try await uploadSecurely(
                data: compressedData,
                filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg",
                uploadType: "location",
                metadata: metadata
            )
            
            uploadProgress = 0.9
            
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] ✅ Secure upload complete")
                print("[PhotoUpload] File ID: \(secureResponse.upload.fileId)")
                print("[PhotoUpload] URL: \(secureResponse.upload.url)")
            }
            #endif
            
            // Step 4: Associate photo with location
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] Associating photo with location \(locationId)...")
            }
            #endif
            
            let associateRequest = AssociatePhotoRequest(
                fileId: secureResponse.upload.fileId,
                filePath: secureResponse.upload.filePath,
                url: secureResponse.upload.url,
                thumbnailUrl: secureResponse.upload.thumbnailUrl,
                width: secureResponse.upload.width,
                height: secureResponse.upload.height,
                caption: caption,
                gpsLatitude: location?.coordinate.latitude,
                gpsLongitude: location?.coordinate.longitude,
                gpsAltitude: location?.altitude
            )
            
            let photo: Photo = try await apiClient.post(
                "/api/locations/\(locationId)/photos",
                body: associateRequest
            )
            
            uploadProgress = 1.0
            
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] ✅ Photo associated! ID: \(photo.id)")
            }
            #endif
            
            isUploading = false
            return photo
            
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            
            #if DEBUG
            if config.enableDebugLogging {
                print("[PhotoUpload] ❌ Upload failed: \(error)")
            }
            #endif
            
            throw error
        }
    }
    
    // MARK: - Secure Upload
    
    /// Upload photo via secure server endpoint with virus scanning
    /// - Parameters:
    ///   - data: Image data (JPEG)
    ///   - filename: Original filename
    ///   - uploadType: Type of upload (location, avatar, banner)
    ///   - metadata: Optional GPS/EXIF metadata
    /// - Returns: SecureUploadResponse with CDN URL and file details
    private func uploadSecurely(
        data: Data,
        filename: String,
        uploadType: String,
        metadata: [String: Any]?
    ) async throws -> SecureUploadResponse {
        
        // Get auth token
        guard let accessToken = KeychainService.shared.getAccessToken() else {
            throw PhotoUploadError.unauthorized
        }
        
        // Build multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        // Add photo file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add uploadType
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"uploadType\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadType)\r\n".data(using: .utf8)!)
        
        // Add metadata if present
        if let metadata = metadata {
            if let metadataJson = try? JSONSerialization.data(withJSONObject: metadata) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
                body.append(metadataJson)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Build request
        let uploadURL = config.backendURL.appendingPathComponent("/api/photos/upload")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[PhotoUpload] POST \(uploadURL.absoluteString)")
            print("[PhotoUpload] Body size: \(body.count / 1024)KB")
        }
        #endif
        
        // Send request
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotoUploadError.invalidResponse
        }
        
        #if DEBUG
        if config.enableDebugLogging {
            print("[PhotoUpload] Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("[PhotoUpload] Response: \(responseString.prefix(500))")
            }
        }
        #endif
        
        // Handle status codes
        switch httpResponse.statusCode {
        case 200, 201:
            // Parse response - backend wraps in { data: ... }
            let decoder = JSONDecoder()
            
            // Try to decode wrapped response first
            if let wrapped = try? decoder.decode(WrappedSecureUploadResponse.self, from: responseData) {
                return wrapped.data
            }
            
            // Fallback to direct response
            return try decoder.decode(SecureUploadResponse.self, from: responseData)
            
        case 400:
            // Parse error message
            if let errorResponse = try? JSONDecoder().decode(UploadErrorResponse.self, from: responseData) {
                switch errorResponse.code {
                case "SECURITY_VIOLATION":
                    throw PhotoUploadError.virusScanFailed(errorResponse.error)
                case "INVALID_FILE_TYPE":
                    throw PhotoUploadError.invalidFileType(errorResponse.error)
                case "FILE_TOO_LARGE":
                    throw PhotoUploadError.fileTooLarge(errorResponse.error)
                default:
                    throw PhotoUploadError.serverError(errorResponse.error)
                }
            }
            throw PhotoUploadError.serverError("Bad request")
            
        case 401:
            throw PhotoUploadError.unauthorized
            
        default:
            throw PhotoUploadError.serverError("Server error (\(httpResponse.statusCode))")
        }
    }
    
    /// Build metadata dictionary for upload
    private func buildUploadMetadata(location: CLLocation?) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        if let loc = location {
            metadata["hasGPS"] = true
            metadata["lat"] = loc.coordinate.latitude
            metadata["lng"] = loc.coordinate.longitude
            metadata["altitude"] = loc.altitude
        } else {
            metadata["hasGPS"] = false
        }
        
        // Add device info (will be sanitized server-side)
        metadata["camera"] = [
            "make": "Apple",
            "model": UIDevice.current.model
        ]
        
        return metadata
    }
    
}

// MARK: - Request/Response Models

/// Request to associate uploaded photo with a location
struct AssociatePhotoRequest: Codable {
    let fileId: String
    let filePath: String
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let caption: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let gpsAltitude: Double?
}

/// Wrapped response from /api/photos/upload
struct WrappedSecureUploadResponse: Codable {
    let data: SecureUploadResponse
}

/// Error response from upload endpoint
struct UploadErrorResponse: Codable {
    let error: String
    let code: String?
}

// MARK: - Errors

enum PhotoUploadError: Error, LocalizedError {
    case compressionFailed
    case unauthorized
    case invalidResponse
    case virusScanFailed(String)
    case invalidFileType(String)
    case fileTooLarge(String)
    case serverError(String)
    // Legacy errors (for backwards compatibility)
    case imagekitUploadFailed
    case invalidImageKitResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .invalidResponse:
            return "Invalid response from server"
        case .virusScanFailed(let message):
            return "Security check failed: \(message)"
        case .invalidFileType(let message):
            return "Invalid file type: \(message)"
        case .fileTooLarge(let message):
            return "File too large: \(message)"
        case .serverError(let message):
            return "Upload failed: \(message)"
        case .imagekitUploadFailed:
            return "Failed to upload image"
        case .invalidImageKitResponse(let message):
            return "Upload error: \(message)"
        }
    }
}
