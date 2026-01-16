import Foundation
import UIKit
import CoreLocation
import Combine

/// Service for uploading photos to backend via ImageKit
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
            
            // Step 3: Upload to ImageKit using SDK
            if config.enableDebugLogging {
                print("[PhotoUpload] Uploading to ImageKit...")
            }
            
            let imagekitResponse = try await uploadToImageKit(
                data: compressedData,
                uploadParams: uploadResponse
            )
            
            uploadProgress = 0.8
            
            if config.enableDebugLogging {
                print("[PhotoUpload] Upload to ImageKit complete")
                print("[PhotoUpload] ImageKit fileId: \(imagekitResponse.fileId)")
                print("[PhotoUpload] ImageKit URL: \(imagekitResponse.url)")
            }
            
            // Step 4: Confirm upload with backend
            if config.enableDebugLogging {
                print("[PhotoUpload] Confirming upload...")
            }
            
            let confirmRequest = ConfirmUploadRequest(
                imagekitFileId: imagekitResponse.fileId,
                imagekitUrl: imagekitResponse.url
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
    
    /// Upload file to ImageKit using multipart/form-data
    private func uploadToImageKit(
        data: Data,
        uploadParams: RequestUploadResponse
    ) async throws -> ImageKitUploadResponse {
        if config.enableDebugLogging {
            print("[PhotoUpload] ImageKit multipart upload starting...")
            print("[PhotoUpload] Image data size: \(data.count) bytes")
            print("[PhotoUpload] Folder (raw): \(uploadParams.folder)")
            print("[PhotoUpload] Folder (cleaned): \(uploadParams.folder.hasPrefix("/") ? String(uploadParams.folder.dropFirst()) : uploadParams.folder)")
            print("[PhotoUpload] Filename: \(uploadParams.fileName)")
        }
        
        // Create multipart form data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://upload.imagekit.io/api/v1/files/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Clean folder path - ImageKit doesn't want leading slash
        let cleanFolder = uploadParams.folder.hasPrefix("/") 
            ? String(uploadParams.folder.dropFirst()) 
            : uploadParams.folder
        
        // Add form fields
        let fields: [String: String] = [
            "publicKey": uploadParams.publicKey,
            "signature": uploadParams.signature,
            "expire": String(uploadParams.expire),
            "token": uploadParams.uploadToken,
            "fileName": uploadParams.fileName,
            "folder": cleanFolder  // Use cleaned folder without leading slash
        ]
        
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(uploadParams.fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotoUploadError.imagekitUploadFailed
        }
        
        if config.enableDebugLogging {
            print("[PhotoUpload] ImageKit response status: \(httpResponse.statusCode)")
        }
        
        guard httpResponse.statusCode == 200 else {
            if config.enableDebugLogging {
                print("[PhotoUpload] ImageKit upload failed with status: \(httpResponse.statusCode)")
                if let errorString = String(data: responseData, encoding: .utf8) {
                    print("[PhotoUpload] Error response: \(errorString)")
                }
            }
            throw PhotoUploadError.imagekitUploadFailed
        }
        
        // DEBUG: Log raw response to see actual field names
        if config.enableDebugLogging {
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("[PhotoUpload] ✅ ImageKit raw response: \(responseString)")
            }
        }
        
        // Parse response
        let decoder = JSONDecoder()
        do {
            let imagekitResponse = try decoder.decode(ImageKitUploadResponse.self, from: responseData)
            
            // Validate critical fields
            guard !imagekitResponse.fileId.isEmpty else {
                if config.enableDebugLogging {
                    print("[PhotoUpload] ❌ ERROR: ImageKit returned empty fileId")
                }
                throw PhotoUploadError.invalidImageKitResponse("Empty fileId")
            }
            
            guard !imagekitResponse.url.isEmpty else {
                if config.enableDebugLogging {
                    print("[PhotoUpload] ❌ ERROR: ImageKit returned empty URL")
                }
                throw PhotoUploadError.invalidImageKitResponse("Empty URL")
            }
            
            if config.enableDebugLogging {
                print("[PhotoUpload] ImageKit upload successful!")
                print("[PhotoUpload] File ID: \(imagekitResponse.fileId)")
                print("[PhotoUpload] URL: \(imagekitResponse.url)")
            }
            
            return imagekitResponse
            
        } catch let DecodingError.keyNotFound(key, context) {
            if config.enableDebugLogging {
                print("[PhotoUpload] ❌ ERROR: Missing key '\(key.stringValue)' in ImageKit response")
                print("[PhotoUpload] Context: \(context.debugDescription)")
            }
            throw PhotoUploadError.invalidImageKitResponse("Missing key: \(key.stringValue)")
            
        } catch let DecodingError.typeMismatch(type, context) {
            if config.enableDebugLogging {
                print("[PhotoUpload] ❌ ERROR: Type mismatch for '\(type)' in ImageKit response")
                print("[PhotoUpload] Context: \(context.debugDescription)")
            }
            throw PhotoUploadError.invalidImageKitResponse("Type mismatch: \(type)")
            
        } catch {
            if config.enableDebugLogging {
                print("[PhotoUpload] ❌ ERROR: Failed to decode ImageKit response: \(error)")
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print("[PhotoUpload] Raw response: \(responseString)")
                }
            }
            throw PhotoUploadError.invalidImageKitResponse(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum PhotoUploadError: Error, LocalizedError {
    case compressionFailed
    case imagekitUploadFailed
    case invalidImageKitResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .imagekitUploadFailed:
            return "Failed to upload to ImageKit"
        case .invalidImageKitResponse(let message):
            return "Invalid ImageKit response: \(message)"
        }
    }
}
