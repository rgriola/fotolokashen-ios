import SwiftUI

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
            ProfileLocationDetailView(
                socialLocation: socialLocation,
                ownerUsername: username,
                ownerDisplayName: profile?.name ?? username
            )
        }
        .overlay {
            if isLoadingProfile {
                ProgressView("Loading profile...")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            if let bannerURL = profile?.bannerURL {
                AsyncImage(url: bannerURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.brandPurple.opacity(0.3))
                }
                .frame(height: 120)
                .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.brandPurple.opacity(0.6), .brandPurple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
            }

            // Avatar
            HStack {
                avatarView
                    .offset(y: 24)
                    .padding(.leading, 16)
                Spacer()
            }
        }
        .padding(.bottom, 28)
    }

    private var avatarView: some View {
        Group {
            if let avatarURL = profile?.avatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsPlaceholder
                }
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
            } else {
                initialsPlaceholder
            }
        }
    }

    private var initialsPlaceholder: some View {
        Circle()
            .fill(Color.brandPurple)
            .frame(width: 68, height: 68)
            .overlay(
                Text(profile?.initials ?? String(username.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
    }

    // MARK: - Profile Info Section

    private func profileInfoSection(_ profile: PublicUser) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.headline)
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
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                // Followers
                Button {
                    showFollowers = true
                } label: {
                    statItem(count: followersCount, label: "Followers")
                }
                .buttonStyle(.plain)

                Spacer()

                // Divider
                Divider().frame(height: 28)

                Spacer()

                // Following
                Button {
                    showFollowing = true
                } label: {
                    statItem(count: followingCount, label: "Following")
                }
                .buttonStyle(.plain)

                Spacer()

                // Divider
                Divider().frame(height: 28)

                Spacer()

                // Locations
                statItem(count: profile?.publicLocationCount ?? 0, label: "Locations")

                Spacer()
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)

            // Follow Button
            if followStatus != nil {
                followButton
                    .padding(.horizontal, 16)
            }
        }
    }

    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
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
            .background(followStatus?.isFollowing == true ? Color(.systemGray5) : Color.brandPurple)
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
                        .background(Color.brandPurple)
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
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let staticMapUrl = StaticMapHelper.thumbnailMapURL(
                latitude: socialLocation.location.lat,
                longitude: socialLocation.location.lng
            ) {
                // Show static map when no photo available
                AsyncImage(url: staticMapUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
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
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Profile Location Detail View

/// Detail view shown when tapping a location card in a public profile
struct ProfileLocationDetailView: View {
    let socialLocation: SocialLocation
    let ownerUsername: String
    let ownerDisplayName: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoIndex: Int = 0
    @State private var showFullScreenGallery = false

    private var location: SocialLocationDetail { socialLocation.location }
    private var photos: [LocationPhoto] { location.photos ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Photo Gallery or Static Map
                    photoSection
                        .frame(height: 220)

                    VStack(alignment: .leading, spacing: 16) {
                        // Type Badge
                        if let type = location.type, !type.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: LocationTypeColors.icon(for: type))
                                    .font(.caption)
                                Text(type)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(LocationTypeColors.uiColor(for: type)))
                            .clipShape(Capsule())
                        }

                        // Location Name
                        Text(location.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        // Address
                        if let address = location.address, !address.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // City/State
                        if let cityState = formatCityState() {
                            HStack(spacing: 8) {
                                Image(systemName: "building.2")
                                    .foregroundColor(.secondary)
                                Text(cityState)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Caption
                        if let caption = socialLocation.caption, !caption.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Caption")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(caption)
                                    .font(.body)
                            }
                            .padding(.top, 4)
                        }

                        // Saved date
                        if let savedAt = socialLocation.savedAt {
                            Text("Saved \(formatSavedDate(savedAt))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Saved by user
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.brandPurple.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(ownerUsername.prefix(1)).uppercased())
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.brandPurple)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Saved by")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ownerDisplayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("@\(ownerUsername)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let url = URL(string: "https://fotolokashen.com/\(ownerUsername)/locations/\(socialLocation.id)") {
                        ShareLink(
                            item: url,
                            subject: Text(location.name),
                            message: Text(location.address ?? "")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullScreenGallery) {
                ProfilePhotoGalleryView(
                    photos: photos,
                    selectedIndex: $selectedPhotoIndex
                )
            }
        }
    }

    // MARK: - Photo Section

    @ViewBuilder
    private var photoSection: some View {
        if !photos.isEmpty {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    AsyncImage(url: URL(string: "https://ik.imagekit.io/rgriola\(photo.imagekitFilePath)")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(ProgressView())
                    }
                    .tag(index)
                    .onTapGesture {
                        showFullScreenGallery = true
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .overlay(alignment: .topTrailing) {
                if photos.count > 1 {
                    Text("\(selectedPhotoIndex + 1)/\(photos.count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
        } else if let staticMapUrl = StaticMapHelper.thumbnailMapURL(
            latitude: location.lat,
            longitude: location.lng
        ) {
            AsyncImage(url: staticMapUrl) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(ProgressView())
            }
            .overlay(
                Image(systemName: "map.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(8),
                alignment: .topTrailing
            )
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: "mappin.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                )
        }
    }

    // MARK: - Helpers

    private func formatCityState() -> String? {
        let parts = [location.city, location.state].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func formatSavedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

// MARK: - Profile Photo Gallery View (Full Screen)

/// Full-screen photo gallery for profile location photos
struct ProfilePhotoGalleryView: View {
    let photos: [LocationPhoto]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    AsyncImage(url: URL(string: "https://ik.imagekit.io/rgriola\(photo.imagekitFilePath)")) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            // Close button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }

            // Photo counter
            VStack {
                Spacer()
                Text("\(selectedIndex + 1) of \(photos.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 40)
            }
        }
    }
}