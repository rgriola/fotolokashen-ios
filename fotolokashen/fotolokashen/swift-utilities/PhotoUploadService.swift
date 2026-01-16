import Foundation
import UIKit
import CoreLocation
import Combine

/// Service for uploading photos to backend
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
    
    /// Upload photo to a location
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
            // Step 1: Compress image
            if config.enableDebugLogging {
                print("[PhotoUpload] Compressing image...")
            }
            
            guard let compressedData = ImageCompressor.compress(image) else {
                throw PhotoUploadError.compressionFailed
            }
            
            uploadProgress = 0.2
            
            if config.enableDebugLogging {
                print("[PhotoUpload] Compressed to \(compressedData.count / 1024)KB")
            }
            
            // Step 2: Request upload URL from backend
            if config.enableDebugLogging {
                print("[PhotoUpload] Requesting upload URL...")
            }
            
            let uploadRequest = RequestUploadRequest(
                filename: "photo_\(Date().timeIntervalSince1970).jpg",
                mimeType: "image/jpeg",
                size: compressedData.count,
                width: nil,
                height: nil,
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                gpsLatitude: location?.coordinate.latitude,
                gpsLongitude: location?.coordinate.longitude,
                gpsAltitude: location?.altitude,
                gpsAccuracy: location?.horizontalAccuracy,
                cameraMake: nil,
                cameraModel: nil,
                iso: nil,
                focalLength: nil,
                aperture: nil,
                shutterSpeed: nil
            )
            
            let uploadResponse: RequestUploadResponse = try await apiClient.post(
                "/api/locations/\(locationId)/photos/request-upload",
                body: uploadRequest
            )
            
            uploadProgress = 0.4
            
            if config.enableDebugLogging {
                print("[PhotoUpload] Upload URL received")
            }
            
            // Step 3: Upload to ImageKit
            if config.enableDebugLogging {
                print("[PhotoUpload] Uploading to ImageKit...")
            }
            
            try await uploadToImageKit(
                data: compressedData,
                uploadParams: uploadResponse
            )
            
            uploadProgress = 0.8
            
            if config.enableDebugLogging {
                print("[PhotoUpload] Upload to ImageKit complete")
            }
            
            // Step 4: Confirm upload with backend
            if config.enableDebugLogging {
                print("[PhotoUpload] Confirming upload...")
            }
            
            let confirmRequest = ConfirmUploadRequest(
                imagekitFileId: uploadResponse.fileName,
                imagekitUrl: uploadResponse.uploadUrl
            )
            
            let confirmResponse: ConfirmUploadResponse = try await apiClient.post(
                "/api/locations/\(locationId)/photos/\(uploadResponse.photoId)/confirm",
                body: confirmRequest
            )
            
            uploadProgress = 1.0
            
            if config.enableDebugLogging {
                print("[PhotoUpload] Upload complete! Photo ID: \(confirmResponse.photo.id)")
            }
            
            isUploading = false
            
            // Return a basic Photo object
            return Photo(
                id: confirmResponse.photo.id,
                imagekitFilePath: confirmResponse.photo.imagekitFilePath,
                url: confirmResponse.photo.url,
                thumbnailUrl: confirmResponse.photo.url,
                caption: caption,
                width: nil,
                height: nil,
                uploadedAt: confirmResponse.photo.uploadedAt,
                gpsLatitude: location?.coordinate.latitude,
                gpsLongitude: location?.coordinate.longitude,
                isPrimary: false,
                fileSize: compressedData.count,
                mimeType: "image/jpeg"
            )
            
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            
            if config.enableDebugLogging {
                print("[PhotoUpload] Upload failed: \(error)")
            }
            
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Upload file to ImageKit
    private func uploadToImageKit(
        data: Data,
        uploadParams: RequestUploadResponse
    ) async throws {
        guard let url = uploadParams.url else {
            throw PhotoUploadError.imagekitUploadFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(uploadParams.fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add other fields
        let fields: [String: String] = [
            "fileName": uploadParams.fileName,
            "signature": uploadParams.signature,
            "expire": String(uploadParams.expire),
            "token": uploadParams.uploadToken,
            "publicKey": uploadParams.publicKey,
            "folder": uploadParams.folder
        ]
        
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PhotoUploadError.imagekitUploadFailed
        }
    }
}

// MARK: - Errors

enum PhotoUploadError: Error, LocalizedError {
    case compressionFailed
    case imagekitUploadFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .imagekitUploadFailed:
            return "Failed to upload to ImageKit"
        }
    }
}
