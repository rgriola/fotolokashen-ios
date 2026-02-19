import SwiftUI

/// Profile view with avatar/banner display and profile edit form
/// Matches web app's /profile Account tab functionality
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
            bannerView
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()

            // Avatar
            HStack(alignment: .bottom) {
                avatarView
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

    private var bannerView: some View {
        Group {
            if let bannerURL = authService.currentUser?.bannerURL {
                AsyncImage(url: bannerURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                    case .failure:
                        bannerPlaceholder
                    default:
                        bannerPlaceholder
                            .overlay(ProgressView())
                    }
                }
            } else {
                bannerPlaceholder
            }
        }
        .overlay(alignment: .topTrailing) {
            if authService.currentUser?.bannerImage != nil {
                Button {
                    showingDeleteBannerConfirm = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .padding(8)
                }
            }
        }
    }

    private var bannerPlaceholder: some View {
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

    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let avatarURL = authService.currentUser?.avatarURL {
                    #if DEBUG
                    let _ = {
                        if ConfigLoader.shared.enableDebugLogging {
                            print("[ProfileView] Avatar URL: \(avatarURL.absoluteString)")
                            print("[ProfileView] Avatar string: \(authService.currentUser?.avatar ?? "nil")")
                        }
                    }()
                    #endif
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 68, height: 68)
                                .clipped()
                        case .failure(let error):
                            #if DEBUG
                            let _ = {
                                if ConfigLoader.shared.enableDebugLogging {
                                    print("[ProfileView] Avatar load failed: \(error)")
                                }
                            }()
                            #endif
                            avatarPlaceholder
                        default:
                            avatarPlaceholder
                                .overlay(ProgressView())
                        }
                    }
                } else {
                    #if DEBUG
                    let _ = {
                        if ConfigLoader.shared.enableDebugLogging {
                            print("[ProfileView] No avatar URL - avatar field: \(authService.currentUser?.avatar ?? "nil")")
                        }
                    }()
                    #endif
                    avatarPlaceholder
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))

            // Camera button overlay
            Button {
                showingAvatarPicker = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.brandPurple)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
            .offset(x: 2, y: 2)
        }
        .contextMenu {
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

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brandPurple)
            .frame(width: 68, height: 68)
            .overlay(
                Text(authService.currentUser?.initials ?? "?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
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
                VStack(spacing: 2) {
                    Text("\(followersCount)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Followers")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
                VStack(spacing: 2) {
                    Text("\(followingCount)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Following")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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

            FormField(label: "First Name", text: $firstName, placeholder: "First name")
            FormField(label: "Last Name", text: $lastName, placeholder: "Last name")
            FormField(label: "Bio", text: $bio, placeholder: "Tell others about yourself...", isMultiline: true)
        }
        .onChange(of: firstName) { _, _ in checkForChanges() }
        .onChange(of: lastName) { _, _ in checkForChanges() }
        .onChange(of: bio) { _, _ in checkForChanges() }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Location", icon: "mappin.circle.fill")

            FormField(label: "City", text: $city, placeholder: "City")
            FormField(label: "Country", text: $country, placeholder: "Country")
        }
        .onChange(of: city) { _, _ in checkForChanges() }
        .onChange(of: country) { _, _ in checkForChanges() }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Preferences", icon: "gearshape.fill")

            FormField(label: "Language", text: $language, placeholder: "en")
            FormField(label: "Timezone", text: $timezone, placeholder: "America/New_York")

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

// MARK: - Helper Views

struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            if isMultiline {
                TextEditor(text: $text)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
}
