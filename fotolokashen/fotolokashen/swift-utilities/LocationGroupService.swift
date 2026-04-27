import Foundation
import Combine

/// Service for managing location groups (CRUD) and custom group types.
///
/// Uses the same `APIClient` pattern as `LocationService`.
@MainActor
class LocationGroupService: ObservableObject {

    // MARK: - Singleton

    static let shared = LocationGroupService()

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Properties

    private let apiClient = APIClient.shared
    private let config = ConfigLoader.shared

    // MARK: - Location Groups

    /// Fetch all groups for the current user
    func fetchGroups() async throws -> [LocationGroup] {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Fetching groups...")
        }
        #endif

        let response: LocationGroupsResponse = try await apiClient.get("/api/location-groups")

        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Fetched \(response.groups.count) groups")
        }
        #endif

        return response.groups
    }

    /// Fetch a single group with all child locations
    func fetchGroup(id: Int) async throws -> LocationGroup {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Fetching group \(id)...")
        }
        #endif

        struct SingleGroupResponse: Codable {
            let group: LocationGroup
        }

        let response: SingleGroupResponse = try await apiClient.get("/api/location-groups/\(id)")
        return response.group
    }

    /// Create a new location group
    func createGroup(
        name: String,
        type: String? = nil,
        description: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) async throws -> LocationGroup {
        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Creating group: \(name)")
        }
        #endif

        struct CreateGroupRequest: Codable {
            let name: String
            let type: String?
            let description: String?
            let startTime: String?
            let endTime: String?
        }

        let formatter = ISO8601DateFormatter()
        let request = CreateGroupRequest(
            name: name,
            type: type,
            description: description,
            startTime: startTime.map { formatter.string(from: $0) },
            endTime: endTime.map { formatter.string(from: $0) }
        )

        let response: CreateLocationGroupResponse = try await apiClient.post(
            "/api/location-groups",
            body: request
        )

        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Group created with ID: \(response.group.id)")
        }
        #endif

        return response.group
    }

    /// Update group metadata
    func updateGroup(
        id: Int,
        name: String? = nil,
        type: String? = nil,
        description: String? = nil,
        coverPhotoId: Int? = nil
    ) async throws -> LocationGroup {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Updating group \(id)...")
        }
        #endif

        struct UpdateGroupRequest: Codable {
            let name: String?
            let type: String?
            let description: String?
            let coverPhotoId: Int?
        }

        struct UpdateGroupResponse: Codable {
            let group: LocationGroup
        }

        let request = UpdateGroupRequest(
            name: name,
            type: type,
            description: description,
            coverPhotoId: coverPhotoId
        )

        let response: UpdateGroupResponse = try await apiClient.patch(
            "/api/location-groups/\(id)",
            body: request
        )

        return response.group
    }

    /// Delete a group (locations remain, their groupId is nullified)
    func deleteGroup(id: Int) async throws {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Deleting group \(id)...")
        }
        #endif

        let _: EmptyResponse = try await apiClient.delete("/api/location-groups/\(id)")

        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Group \(id) deleted")
        }
        #endif
    }

    // MARK: - Link/Unlink Locations

    /// Add a location to a group (PATCH /api/locations/:id with groupId)
    func addLocationToGroup(locationId: Int, groupId: Int) async throws {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Linking location \(locationId) to group \(groupId)")
        }
        #endif

        struct GroupIdUpdate: Codable {
            let groupId: Int?
        }

        let _: UpdateLocationResponse = try await apiClient.patch(
            "/api/locations/\(locationId)",
            body: GroupIdUpdate(groupId: groupId)
        )
    }

    /// Remove a location from its group
    func removeLocationFromGroup(locationId: Int) async throws {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Unlinking location \(locationId) from group")
        }
        #endif

        struct GroupIdClear: Codable {
            let groupId: Int?
        }

        let _: UpdateLocationResponse = try await apiClient.patch(
            "/api/locations/\(locationId)",
            body: GroupIdClear(groupId: nil)
        )
    }

    // MARK: - Custom Group Types

    /// Fetch preset types + user's custom types
    func fetchGroupTypes() async throws -> (presets: [String], custom: [CustomGroupType]) {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Fetching group types...")
        }
        #endif

        let response: GroupTypesResponse = try await apiClient.get("/api/user-group-types")
        return (response.presets, response.customTypes)
    }

    /// Create a new custom group type
    func createCustomType(name: String) async throws -> CustomGroupType {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Creating custom type: \(name)")
        }
        #endif

        struct CreateTypeRequest: Codable {
            let typeName: String
        }

        let response: CreateCustomTypeResponse = try await apiClient.post(
            "/api/user-group-types",
            body: CreateTypeRequest(typeName: name)
        )

        return response.customType
    }

    /// Delete a custom group type
    func deleteCustomType(name: String) async throws {
        #if DEBUG
        if config.enableDebugLogging {
            print("[LocationGroupService] Deleting custom type: \(name)")
        }
        #endif

        struct DeleteTypeRequest: Codable {
            let typeName: String
        }

        // APIClient.delete may not support body — use a workaround
        let _: EmptyResponse = try await apiClient.delete(
            "/api/user-group-types",
            body: DeleteTypeRequest(typeName: name)
        )
    }
}
