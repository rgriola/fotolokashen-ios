import SwiftUI

/// Profile view with avatar/banner display and profile edit form
/// Matches web app's /profile Account tab functionality
///
// REVIEW: State management — this view has 20+ @State vars.
// Consider extracting into a ProfileViewModel (@StateObject) that holds form state,
// change tracking, and avatar/banner upload logic. Social stats (followers/following counts)
// are also loaded here AND in SettingsView — centralize in one place.
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared

    // Form fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var country = ""
    @State private var language = ""
    @State private var timezone = ""
    @State private var emailNotifications = true

    // Image picker state
    @State private var showingAvatarPicker = false
    @State private var showingBannerPicker = false
    @State private var selectedAvatarImage: UIImage?
    @State private var selectedBannerImage: UIImage?

    // UI state
    @State private var hasChanges = false
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorText = ""
    @State private var showingDeleteAvatarConfirm = false
    @State private var showingDeleteBannerConfirm = false

    // Social stats
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showFollowers = false
    @State private var showFollowing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner + Avatar header
                    profileHeader

                    // Profile info (name & username)
                    if let user = authService.currentUser {
                        profileInfoSection(user)
                    }

                    // Social stats (followers / following)
                    socialStatsBar

                    Divider()
                        .padding(.vertical, 8)

                    // Edit form
                    VStack(spacing: 20) {
                        profileFieldsSection
                        locationSection
                        preferencesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasChanges {
                        Button("Save") {
                            Task { await saveProfile() }
                        }
                        .fontWeight(.semibold)
                        .disabled(userService.isLoading)
                    }
                }
            }
            .onAppear { loadUserData() }
            .sheet(isPresented: $showingAvatarPicker) {
                ImagePicker(image: $selectedAvatarImage)
            }
            .sheet(isPresented: $showingBannerPicker) {
                ImagePicker(image: $selectedBannerImage)
            }
            .onChange(of: selectedAvatarImage) { _, newValue in
                if let image = newValue {
                    Task { await uploadAvatar(image) }
                }
            }
            .onChange(of: selectedBannerImage) { _, newValue in
                if let image = newValue {
                    Task { await uploadBanner(image) }
                }
            }
            .alert("Profile Updated", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your profile has been saved.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }
            .alert("Remove Avatar?", isPresented: $showingDeleteAvatarConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task { await deleteAvatar() }
                }
            }
            .alert("Remove Banner?", isPresented: $showingDeleteBannerConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task { await deleteBanner() }
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            ProfileBannerView(
                bannerURL: authService.currentUser?.bannerURL,
                hasBannerImage: authService.currentUser?.bannerImage != nil,
                onEdit: nil,
                onDelete: { showingDeleteBannerConfirm = true }
            )

            // Avatar + Edit banner button
            HStack(alignment: .bottom) {
                ProfileAvatarView(
                    avatarURL: authService.currentUser?.avatarURL,
                    initials: authService.currentUser?.initials ?? "?",
                    onEdit: { showingAvatarPicker = true },
                    editMenuContent: {
                        Group {
                            if authService.currentUser?.avatar != nil {
                                Button(role: .destructive) {
                                    showingDeleteAvatarConfirm = true
                                } label: {
                                    Label("Remove Avatar", systemImage: "trash")
                                }
                            }
                            Button {
                                showingAvatarPicker = true
                            } label: {
                                Label("Change Avatar", systemImage: "camera")
                            }
                        }
                    }
                )
                .offset(y: 24)
                .padding(.leading, 16)

                Spacer()

                // Edit banner button
                Button {
                    showingBannerPicker = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.brandPurple)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    // MARK: - Profile Info Section

    private func profileInfoSection(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let firstName = user.firstName, let lastName = user.lastName {
                Text("\(firstName) \(lastName)")
                    .font(.headline)
                    .fontWeight(.bold)
            } else if let firstName = user.firstName {
                Text(firstName)
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Social Stats

    private var socialStatsBar: some View {
        HStack(spacing: 0) {
            Spacer()
            
            // Followers
            Button {
                showFollowers = true
            } label: {
                ProfileStatItem(count: followersCount, label: "Followers")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Divider()
                .frame(height: 28)
            
            Spacer()
            
            // Following
            Button {
                showFollowing = true
            } label: {
                ProfileStatItem(count: followingCount, label: "Following")
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showFollowers) {
            if let username = authService.currentUser?.username {
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
        }
        .sheet(isPresented: $showFollowing) {
            if let username = authService.currentUser?.username {
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
        }
        .task {
            await loadSocialStats()
        }
    }

    // MARK: - Form Sections

    private var profileFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Info", icon: "person.fill")

            FormField(label: "First Name", text: $firstName, placeholder: "First name", maxLength: 50)
            FormField(label: "Last Name", text: $lastName, placeholder: "Last name", maxLength: 50)
            FormField(label: "Bio", text: $bio, placeholder: "Tell others about yourself...", isMultiline: true, maxLength: 500)
        }
        .onChange(of: firstName) { _, _ in checkForChanges() }
        .onChange(of: lastName) { _, _ in checkForChanges() }
        .onChange(of: bio) { _, _ in checkForChanges() }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Location", icon: "mappin.circle.fill")

            FormField(label: "City", text: $city, placeholder: "City", maxLength: 100)
            FormField(label: "Country", text: $country, placeholder: "Country", maxLength: 100)
        }
        .onChange(of: city) { _, _ in checkForChanges() }
        .onChange(of: country) { _, _ in checkForChanges() }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Preferences", icon: "gearshape.fill")

            FormField(label: "Language", text: $language, placeholder: "en", maxLength: 10)
            FormField(label: "Timezone", text: $timezone, placeholder: "America/New_York", maxLength: 50)

            Toggle("Email Notifications", isOn: $emailNotifications)
                .tint(.brandPurple)
                .padding(.horizontal, 4)
        }
        .onChange(of: language) { _, _ in checkForChanges() }
        .onChange(of: timezone) { _, _ in checkForChanges() }
        .onChange(of: emailNotifications) { _, _ in checkForChanges() }
    }

    // MARK: - Upload indicator

    @ViewBuilder
    private var uploadOverlay: some View {
        if userService.isUploading {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Uploading...")
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                )
        }
    }

    // MARK: - Actions

    private func loadUserData() {
        guard let user = authService.currentUser else { return }
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        bio = user.bio ?? ""
        city = user.city ?? ""
        country = user.country ?? ""
        language = user.language ?? ""
        timezone = user.timezone ?? ""
        emailNotifications = user.emailNotifications ?? true
    }

    private func loadSocialStats() async {
        guard let username = authService.currentUser?.username else { return }
        do {
            async let followersTask = FollowService.shared.getFollowers(username: username, page: 1, limit: 1)
            async let followingTask = FollowService.shared.getFollowing(username: username, page: 1, limit: 1)
            let (followersResp, followingResp) = try await (followersTask, followingTask)
            followersCount = followersResp.pagination.total
            followingCount = followingResp.pagination.total
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[ProfileView] Failed to load social stats: \(error)")
            }
            #endif
        }
    }

    private func checkForChanges() {
        guard let user = authService.currentUser else { return }
        hasChanges = firstName != (user.firstName ?? "")
            || lastName != (user.lastName ?? "")
            || bio != (user.bio ?? "")
            || city != (user.city ?? "")
            || country != (user.country ?? "")
            || language != (user.language ?? "")
            || timezone != (user.timezone ?? "")
            || emailNotifications != (user.emailNotifications ?? true)
    }

    private func saveProfile() async {
        let request = ProfileUpdateRequest(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            bio: bio.isEmpty ? nil : bio,
            city: city.isEmpty ? nil : city,
            country: country.isEmpty ? nil : country,
            language: language.isEmpty ? nil : language,
            timezone: timezone.isEmpty ? nil : timezone,
            emailNotifications: emailNotifications
        )

        do {
            let updatedUser = try await userService.updateProfile(request)
            authService.currentUser = updatedUser
            hasChanges = false
            showingSaveSuccess = true
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func uploadAvatar(_ image: UIImage) async {
        do {
            _ = try await userService.uploadAvatar(image: image)
            // Refresh user to get new avatar URL
            await authService.fetchCurrentUser()
            selectedAvatarImage = nil
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func uploadBanner(_ image: UIImage) async {
        do {
            _ = try await userService.uploadBanner(image: image)
            await authService.fetchCurrentUser()
            selectedBannerImage = nil
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func deleteAvatar() async {
        do {
            try await userService.deleteAvatar()
            await authService.fetchCurrentUser()
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func deleteBanner() async {
        do {
            try await userService.deleteBanner()
            await authService.fetchCurrentUser()
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
}
