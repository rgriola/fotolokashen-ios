import SwiftUI

/// Edit Profile — all form fields for the user's personal info, avatar, and banner.
/// Extracted from the old ProfileView so it's reachable via Profile → Edit Profile.
struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Banner + Avatar header
                profileHeader

                VStack(spacing: 20) {
                    profileFieldsSection
                    locationSection
                    preferencesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            if let image = newValue { Task { await uploadAvatar(image) } }
        }
        .onChange(of: selectedBannerImage) { _, newValue in
            if let image = newValue { Task { await uploadBanner(image) } }
        }
        .alert("Profile Updated", isPresented: $showingSaveSuccess) {
            Button("Done") { dismiss() }
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
            Button("Remove", role: .destructive) { Task { await deleteAvatar() } }
        }
        .alert("Remove Banner?", isPresented: $showingDeleteBannerConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { Task { await deleteBanner() } }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            ProfileBannerView(
                bannerURL: authService.currentUser?.bannerURL,
                hasBannerImage: authService.currentUser?.bannerImage != nil,
                onEdit: nil,
                onDelete: { showingDeleteBannerConfirm = true }
            )

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
                            Button { showingAvatarPicker = true } label: {
                                Label("Change Avatar", systemImage: "camera")
                            }
                        }
                    }
                )
                .offset(y: 24)
                .padding(.leading, 16)

                Spacer()

                Button { showingBannerPicker = true } label: {
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
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthService())
    }
}
