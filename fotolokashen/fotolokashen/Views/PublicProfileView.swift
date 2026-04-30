import SwiftUI
import Kingfisher

/// Public profile view for viewing another user's profile
/// Shows banner, avatar, bio, follow button, follower/following counts, and public locations
struct PublicProfileView: View {
    let username: String

    @ObservedObject private var followService = FollowService.shared
    @State private var profile: PublicUser?
    @State private var followStatus: FollowStatus?
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var locations: [SocialLocation] = []
    @State private var isLoadingProfile = true
    @State private var isLoadingLocations = false
    @State private var isTogglingFollow = false
    @State private var errorMessage: String?
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var selectedLocation: SocialLocation?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Banner + Avatar Header
                headerSection

                // Profile Info
                if let profile = profile {
                    profileInfoSection(profile)
                }

                // Stats & Follow Button
                if profile != nil {
                    statsSection
                }

                Divider()
                    .padding(.vertical, 8)

                // Public Locations
                locationsSection
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showFollowers) {
            NavigationStack {
                FollowListView(username: username, mode: .followers)
                    .navigationTitle("Followers")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showFollowers = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showFollowing) {
            NavigationStack {
                FollowListView(username: username, mode: .following)
                    .navigationTitle("Following")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showFollowing = false }
                        }
                    }
            }
        }
        .sheet(item: $selectedLocation) { socialLocation in
            NavigationStack {
                LocationDetailView(
                    socialLocation: socialLocation,
                    ownerUsername: username,
                    ownerDisplayName: profile?.name ?? username
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { selectedLocation = nil }
                    }
                }
            }
        }
        .overlay {
            if isLoadingProfile {
                ProgressView("Loading profile...")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .leading) {
            // Banner
            ProfileBannerView(bannerURL: profile?.bannerURL)

            // Avatar
            ProfileAvatarView(
                avatarURL: profile?.avatarURL,
                initials: profile?.initials ?? String(username.prefix(1)).uppercased()
            )
            .padding(.leading, 16)
        }
    }

    // MARK: - Profile Info Section

    private func profileInfoSection(_ profile: PublicUser) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.title3)
                .fontWeight(.bold)

            Text("@\(profile.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }

            if let joinedAt = profile.joinedAt {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Joined \(formatJoinDate(joinedAt))")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                // Spots
                ProfileStatItem(count: profile?.publicLocationCount ?? 0, label: "Spots")

                Divider().frame(height: 28)

                // Followers
                Button {
                    showFollowers = true
                } label: {
                    ProfileStatItem(count: followersCount, label: "Followers")
                }
                .buttonStyle(.plain)

                Divider().frame(height: 28)

                // Following
                Button {
                    showFollowing = true
                } label: {
                    ProfileStatItem(count: followingCount, label: "Following")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Follow Button
            if followStatus != nil {
                followButton
                    .padding(.horizontal, 16)
            }
        }
    }

    private var followButton: some View {
        Button {
            Task {
                await toggleFollow()
            }
        } label: {
            HStack {
                if isTogglingFollow {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: followStatus?.isFollowing == true ? .primary : .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: followStatus?.isFollowing == true ? "person.badge.minus" : "person.badge.plus")
                    Text(followStatus?.isFollowing == true ? "Following" : "Follow")
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(followStatus?.isFollowing == true ? Color(.systemGray5) : Color.brand)
            .foregroundColor(followStatus?.isFollowing == true ? .primary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isTogglingFollow)
        .padding(.top, 4)
    }

    // MARK: - Locations Section

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Public Locations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !locations.isEmpty {
                    Text("\(locations.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brand)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            if isLoadingLocations {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if locations.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "mappin.slash")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No public locations")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ], spacing: 6) {
                    ForEach(locations) { socialLocation in
                        Button {
                            selectedLocation = socialLocation
                        } label: {
                            locationCard(socialLocation)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private func locationCard(_ socialLocation: SocialLocation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail
            if let thumbnailUrl = socialLocation.location.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .onFailureView {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                    .fade(duration: 0.2)
                    .scaledToFill()
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let staticMapUrl = StaticMapHelper.thumbnailMapURL(
                latitude: socialLocation.location.lat,
                longitude: socialLocation.location.lng
            ) {
                // Show static map when no photo available
                KFImage(staticMapUrl)
                    .resizable()
                    .placeholder {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(ProgressView())
                    }
                    .fade(duration: 0.2)
                    .scaledToFill()
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        // Subtle map indicator badge
                        Image(systemName: "map.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                        .padding(4),
                    alignment: .topTrailing
                )
            } else {
                // Fallback if static map URL fails
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 88)
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Name
            Text(socialLocation.location.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            // Location type badge
            if let type = socialLocation.location.type {
                Text(type)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Actions

    private func loadProfile() async {
        isLoadingProfile = true
        errorMessage = nil

        do {
            // Load profile, follow status, and counts in parallel
            async let profileTask = followService.getPublicProfile(username: username)
            async let statusTask = followService.getFollowStatus(username: username)
            async let followersTask = followService.getFollowers(username: username, page: 1, limit: 1)
            async let followingTask = followService.getFollowing(username: username, page: 1, limit: 1)

            let (loadedProfile, loadedStatus, followersResp, followingResp) = try await (
                profileTask, statusTask, followersTask, followingTask
            )

            profile = loadedProfile
            followStatus = loadedStatus
            followersCount = followersResp.pagination.total
            followingCount = followingResp.pagination.total

            isLoadingProfile = false

            // Load locations after profile
            await loadLocations()
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[PublicProfileView] Error loading profile: \(error)")
            }
            #endif
            errorMessage = error.localizedDescription
            isLoadingProfile = false
        }
    }

    private func loadLocations() async {
        isLoadingLocations = true
        do {
            let response = try await followService.getUserLocations(username: username, page: 1, limit: 50)
            locations = response.locations
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[PublicProfileView] Error loading locations: \(error)")
            }
            #endif
        }
        isLoadingLocations = false
    }

    private func toggleFollow() async {
        guard let currentStatus = followStatus else { return }
        isTogglingFollow = true

        do {
            if currentStatus.isFollowing {
                _ = try await followService.unfollow(username: username)
                followStatus = FollowStatus(isFollowing: false, isFollowedBy: currentStatus.isFollowedBy, followedAt: nil)
                followersCount = max(0, followersCount - 1)
            } else {
                let response = try await followService.follow(username: username)
                followStatus = FollowStatus(
                    isFollowing: true,
                    isFollowedBy: currentStatus.isFollowedBy,
                    followedAt: response.followedAt
                )
                followersCount += 1
            }
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[PublicProfileView] Toggle follow failed: \(error)")
            }
            #endif
        }

        isTogglingFollow = false
    }

    // MARK: - Helpers

    private func formatJoinDate(_ dateString: String) -> String {
        // Try ISO8601 with fractional seconds first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return joinDateDisplay(date)
        }
        // Fallback to standard ISO8601
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return joinDateDisplay(date)
        }
        return dateString
    }

    private func joinDateDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
