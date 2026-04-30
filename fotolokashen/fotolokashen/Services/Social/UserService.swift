import Foundation
import UIKit
import Combine

/// Service for user profile management
/// Handles profile updates, privacy settings, and avatar/banner uploads
@MainActor
class UserService: ObservableObject {

    // MARK: - Singleton

    static let shared = UserService()

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0

    // MARK: - Properties

    private let apiClient = APIClient.shared
    private let config = ConfigLoader.shared

    // MARK: - Profile

    /// Update user profile fields via PATCH /api/v1/users/me
    func updateProfile(_ request: ProfileUpdateRequest) async throws -> User {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: V1MeResponse = try await apiClient.patch(
                "/api/v1/users/me",
                body: request
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[UserService] Profile updated for user: \(response.user.username)")
            }
            #endif

            return response.user
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[UserService] Profile update failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - Privacy

    /// Update privacy settings via PATCH /api/v1/users/me
    func updatePrivacy(_ request: PrivacyUpdateRequest) async throws -> User {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: V1MeResponse = try await apiClient.patch(
                "/api/v1/users/me",
                body: request
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[UserService] Privacy settings updated")
            }
            #endif

            return response.user
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[UserService] Privacy update failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - Avatar Upload

    /// Upload avatar image via POST /api/auth/avatar (FormData)
    /// Server performs virus scanning, validation, and CDN upload
    func uploadAvatar(image: UIImage) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        guard let imageData = ImageCompressor.compress(image) else {
            throw UserServiceError.compressionFailed
        }

        uploadProgress = 0.3

        let response = try await uploadImage(
            data: imageData,
            endpoint: "/api/auth/avatar",
            fieldName: "avatar",
            filename: "avatar_\(Int(Date().timeIntervalSince1970)).jpg"
        )

        uploadProgress = 1.0

        guard let url = response.avatarUrl else {
            throw UserServiceError.noUrlInResponse
        }

        #if DEBUG
        if config.enableDebugLogging {
            print("[UserService] Avatar uploaded: \(url)")
        }
        #endif

        return url
    }

    /// Delete avatar via DELETE /api/auth/avatar
    func deleteAvatar() async throws {
        isLoading = true
        defer { isLoading = false }

        let _: SuccessResponse = try await apiClient.delete("/api/auth/avatar")

        #if DEBUG
        if config.enableDebugLogging {
            print("[UserService] Avatar deleted")
        }
        #endif
    }

    // MARK: - Account Deletion

    /// Permanently delete the authenticated user's account via DELETE /api/auth/delete-account
    /// Server deletes all user data (locations, photos, follows, sessions)
    func deleteAccount() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let _: SuccessResponse = try await apiClient.delete("/api/auth/delete-account")

            #if DEBUG
            if config.enableDebugLogging {
                print("[UserService] Account deleted successfully")
            }
            #endif
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[UserService] Account deletion failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - Banner Upload

    /// Upload banner image via POST /api/auth/banner (FormData)
    /// Server performs virus scanning, validation, and CDN upload
    func uploadBanner(image: UIImage) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        guard let imageData = ImageCompressor.compress(image) else {
            throw UserServiceError.compressionFailed
        }

        uploadProgress = 0.3

        let response = try await uploadImage(
            data: imageData,
            endpoint: "/api/auth/banner",
            fieldName: "banner",
            filename: "banner_\(Int(Date().timeIntervalSince1970)).jpg"
        )

        uploadProgress = 1.0

        guard let url = response.bannerUrl else {
            throw UserServiceError.noUrlInResponse
        }

        #if DEBUG
        if config.enableDebugLogging {
            print("[UserService] Banner uploaded: \(url)")
        }
        #endif

        return url
    }

    /// Delete banner via DELETE /api/auth/banner
    func deleteBanner() async throws {
        isLoading = true
        defer { isLoading = false }

        let _: SuccessResponse = try await apiClient.delete("/api/auth/banner")

        #if DEBUG
        if config.enableDebugLogging {
            print("[UserService] Banner deleted")
        }
        #endif
    }

    // MARK: - Private Helpers

    /// Generic multipart image upload for avatar/banner
    private func uploadImage(
        data: Data,
        endpoint: String,
        fieldName: String,
        filename: String
    ) async throws -> ImageUploadResponse {

        guard let accessToken = KeychainService.shared.getAccessToken() else {
            throw UserServiceError.unauthorized
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Build request
        let url = config.backendURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        uploadProgress = 0.5

        #if DEBUG
        if config.enableDebugLogging {
            print("[UserService] POST \(url.absoluteString) (\(body.count / 1024)KB)")
        }
        #endif

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserServiceError.invalidResponse
        }

        uploadProgress = 0.9

        #if DEBUG
        if config.enableDebugLogging {
            print("[UserService] Response status: \(httpResponse.statusCode)")
        }
        #endif

        switch httpResponse.statusCode {
        case 200, 201:
            // The backend wraps in { data: { success, avatarUrl/bannerUrl } }
            // Try wrapped first, then direct
            let decoder = JSONDecoder()
            if let wrapped = try? decoder.decode(WrappedImageUploadResponse.self, from: responseData) {
                return wrapped.data
            }
            return try decoder.decode(ImageUploadResponse.self, from: responseData)

        case 400:
            if let errorResponse = try? JSONDecoder().decode(UploadErrorResponse.self, from: responseData) {
                throw UserServiceError.serverError(errorResponse.error)
            }
            throw UserServiceError.serverError("Bad request")

        case 401:
            throw UserServiceError.unauthorized

        default:
            throw UserServiceError.serverError("Server error (\(httpResponse.statusCode))")
        }
    }
}

// MARK: - Wrapped Response

private struct WrappedImageUploadResponse: Codable {
    let data: ImageUploadResponse
}

// MARK: - Errors

enum UserServiceError: Error, LocalizedError {
    case compressionFailed
    case unauthorized
    case invalidResponse
    case noUrlInResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .invalidResponse:
            return "Invalid response from server"
        case .noUrlInResponse:
            return "Server did not return an image URL"
        case .serverError(let message):
            return message
        }
    }
}
