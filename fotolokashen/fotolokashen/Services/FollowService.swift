import Foundation
import Combine

/// Service for follow/unfollow operations and social data
/// Handles follow relationships, public profiles, followers/following lists, and social locations
@MainActor
class FollowService: ObservableObject {

    // MARK: - Singleton

    static let shared = FollowService()

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Properties

    private let apiClient = APIClient.shared
    private let config = ConfigLoader.shared

    // MARK: - Follow / Unfollow

    /// Follow a user by username
    /// POST /api/v1/users/{username}/follow
    func follow(username: String) async throws -> FollowResponse {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // POST with empty body
            let response: FollowResponse = try await apiClient.post(
                "/api/v1/users/\(username)/follow",
                body: EmptyBody()
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Followed @\(username)")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Follow failed: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Unfollow a user by username
    /// POST /api/v1/users/{username}/unfollow
    func unfollow(username: String) async throws -> UnfollowResponse {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: UnfollowResponse = try await apiClient.post(
                "/api/v1/users/\(username)/unfollow",
                body: EmptyBody()
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Unfollowed @\(username)")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Unfollow failed: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Follow Status

    /// Check follow status between current user and another user
    /// GET /api/v1/users/me/follow-status/{username}
    func getFollowStatus(username: String) async throws -> FollowStatus {
        do {
            let response: FollowStatus = try await apiClient.get(
                "/api/v1/users/me/follow-status/\(username)"
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Follow status for @\(username): following=\(response.isFollowing), followedBy=\(response.isFollowedBy)")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get follow status failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - Public Profile

    /// Fetch a user's public profile
    /// GET /api/v1/users/{username}
    func getPublicProfile(username: String) async throws -> PublicUser {
        do {
            let response: PublicUser = try await apiClient.get(
                "/api/v1/users/\(username)",
                authenticated: false
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Fetched profile for @\(username)")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get public profile failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - Followers / Following Lists

    /// Fetch a user's followers list (paginated)
    /// GET /api/v1/users/{username}/followers?page={page}&limit={limit}
    func getFollowers(username: String, page: Int = 1, limit: Int = 20) async throws -> FollowersResponse {
        do {
            let response: FollowersResponse = try await apiClient.get(
                "/api/v1/users/\(username)/followers?page=\(page)&limit=\(limit)",
                authenticated: false
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Fetched \(response.followers.count) followers for @\(username) (page \(page))")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get followers failed: \(error)")
            }
            #endif
            throw error
        }
    }

    /// Fetch a user's following list (paginated)
    /// GET /api/v1/users/{username}/following?page={page}&limit={limit}
    func getFollowing(username: String, page: Int = 1, limit: Int = 20) async throws -> FollowingResponse {
        do {
            let response: FollowingResponse = try await apiClient.get(
                "/api/v1/users/\(username)/following?page=\(page)&limit=\(limit)",
                authenticated: false
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Fetched \(response.following.count) following for @\(username) (page \(page))")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get following failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - Social Locations

    /// Fetch a user's public locations
    /// GET /api/v1/users/{username}/locations?page={page}&limit={limit}
    func getUserLocations(username: String, page: Int = 1, limit: Int = 20) async throws -> UserLocationsResponse {
        do {
            let response: UserLocationsResponse = try await apiClient.get(
                "/api/v1/users/\(username)/locations?page=\(page)&limit=\(limit)",
                authenticated: false
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Fetched \(response.locations.count) locations for @\(username)")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get user locations failed: \(error)")
            }
            #endif
            throw error
        }
    }

    /// Fetch friends' locations for map overlay
    /// GET /api/v1/locations/friends?bounds={bounds}&type={type}
    func getFriendsLocations(
        bounds: MapBounds? = nil,
        type: String? = nil
    ) async throws -> [MapSocialLocation] {
        do {
            var path = "/api/v1/locations/friends"
            var queryItems: [String] = []

            if let bounds = bounds {
                let boundsJSON = "{\"north\":\(bounds.north),\"south\":\(bounds.south),\"east\":\(bounds.east),\"west\":\(bounds.west)}"
                queryItems.append("bounds=\(boundsJSON)")
            }

            if let type = type {
                queryItems.append("type=\(type)")
            }

            if !queryItems.isEmpty {
                path += "?" + queryItems.joined(separator: "&")
            }

            let response: MapSocialLocationsResponse = try await apiClient.get(path)

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Fetched \(response.locations.count) friends' locations")
            }
            #endif

            return response.locations
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get friends locations failed: \(error)")
            }
            #endif
            throw error
        }
    }

    /// Fetch all public locations for map overlay
    /// GET /api/v1/locations/public?bounds={bounds}&type={type}
    func getPublicLocations(
        bounds: MapBounds? = nil,
        type: String? = nil
    ) async throws -> [MapSocialLocation] {
        do {
            var path = "/api/v1/locations/public"
            var queryItems: [String] = []

            if let bounds = bounds {
                let boundsJSON = "{\"north\":\(bounds.north),\"south\":\(bounds.south),\"east\":\(bounds.east),\"west\":\(bounds.west)}"
                queryItems.append("bounds=\(boundsJSON)")
            }

            if let type = type {
                queryItems.append("type=\(type)")
            }

            if !queryItems.isEmpty {
                path += "?" + queryItems.joined(separator: "&")
            }

            let response: MapSocialLocationsResponse = try await apiClient.get(path)

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Fetched \(response.locations.count) public locations")
            }
            #endif

            return response.locations
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get public locations failed: \(error)")
            }
            #endif
            throw error
        }
    }

    // MARK: - People Search

    /// Search for users by query
    /// GET /api/v1/search/users?q={query}&type={type}&limit={limit}&offset={offset}
    func searchUsers(
        query: String,
        type: String = "all",
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> UserSearchResponse {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let path = "/api/v1/search/users?q=\(encodedQuery)&type=\(type)&limit=\(limit)&offset=\(offset)"

            let response: UserSearchResponse = try await apiClient.get(
                path,
                authenticated: false
            )

            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Search found \(response.users.count) users for query '\(query)'")
            }
            #endif

            return response
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Search users failed: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Get username suggestions for autocomplete
    /// GET /api/v1/search/suggestions?q={query}&limit={limit}
    func getSearchSuggestions(query: String, limit: Int = 10) async throws -> [String] {
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let path = "/api/v1/search/suggestions?q=\(encodedQuery)&limit=\(limit)"

            let response: SearchSuggestionsResponse = try await apiClient.get(
                path,
                authenticated: false
            )

            return response.suggestions
        } catch {
            #if DEBUG
            if config.enableDebugLogging {
                print("[FollowService] Get suggestions failed: \(error)")
            }
            #endif
            throw error
        }
    }
}

// MARK: - Helper Types

/// Empty body for POST requests that don't need a body
private struct EmptyBody: Codable {}

/// Map viewport bounds for filtering locations
struct MapBounds {
    let north: Double
    let south: Double
    let east: Double
    let west: Double
}
