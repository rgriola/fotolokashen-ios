import SwiftUI
import PhotosUI
import UIKit

/// Edit Profile — all form fields for the user's personal info, avatar, and banner.
/// Extracted from the old ProfileView so it's reachable via Profile → Edit Profile.
struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    private let userService = UserService.shared
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var state = ""
    @State private var country = ""
    @State private var dateOfBirth: Date? = nil
    @State private var showDatePicker = false

    // Image picker state
    @State private var showingAvatarPicker = false
    @State private var showingBannerPicker = false
    @State private var selectedAvatarImage: UIImage?
    @State private var selectedBannerImage: UIImage?
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedBannerItem: PhotosPickerItem?
    @State private var imageUploadStatus: String?

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
                    imageUploadStatusView
                    profileFieldsSection
                    locationSection
                    birthdaySection
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
        .modifier(
            ProfileImagePickerPresentation(
                showingAvatarPicker: $showingAvatarPicker,
                selectedAvatarItem: $selectedAvatarItem,
                showingBannerPicker: $showingBannerPicker,
                selectedBannerItem: $selectedBannerItem
            )
        )
        .onChange(of: selectedAvatarItem) { _, item in
            guard let item else { return }
            Task { await loadSelectedImage(from: item, isAvatar: true) }
        }

        .onChange(of: selectedBannerItem) { _, item in
            guard let item else { return }
            Task { await loadSelectedImage(from: item, isAvatar: false) }
        }
        .onChange(of: selectedAvatarImage) { _, newValue in
            if let image = newValue {
                let status = "Uploading profile photo…"
                imageUploadStatus = status
                announceImageStatus(status)
                Task { await uploadAvatar(image) }
            }
        }
        .onChange(of: selectedBannerImage) { _, newValue in
            if let image = newValue {
                let status = "Uploading profile banner…"
                imageUploadStatus = status
                announceImageStatus(status)
                Task { await uploadBanner(image) }
            }
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
                    onEdit: {
                        imageUploadStatus = nil
                        showingAvatarPicker = true
                    },
                    editMenuContent: {
                        Group {
                            if authService.currentUser?.avatar != nil {
                                Button(role: .destructive) {
                                    showingDeleteAvatarConfirm = true
                                } label: {
                                    Label("Remove Avatar", systemImage: AppIcons.delete)
                                }

                            }
                            Button {
                                imageUploadStatus = nil
                                showingAvatarPicker = true
                            } label: {
                                Label("Change Avatar", systemImage: AppIcons.camera)
                            }
                        }
                    }
                )
                .offset(y: 24)
                .padding(.leading, 16)

                Spacer()

                Button {
                    imageUploadStatus = nil
                    showingBannerPicker = true
                } label: {
                    Image(systemName: AppIcons.cameraFill)
                        .font(.caption)
                        .foregroundStyle(Color.white)
                        .padding(8)
                        .background(Color.brand)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Change profile banner")
                .accessibilityHint("Opens the photo picker to choose a new profile banner.")
                .padding(.trailing, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var imageUploadStatusView: some View {
        if userService.isUploading || imageUploadStatus != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text(imageUploadStatus ?? "Uploading profile image…")
                    .font(.subheadline)
                if userService.isUploading {
                    ProgressView(value: userService.uploadProgress)
                        .accessibilityLabel("Profile image upload progress")
                        .accessibilityValue(imageUploadProgressValue)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Form Sections

    private var profileFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Info", icon: AppIcons.personFill)
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
            SectionHeader(title: "Location", icon: AppIcons.mapPin)
            FormField(label: "City", text: $city, placeholder: "City", maxLength: 100)
            FormField(label: "State / Province", text: $state, placeholder: "State or Province", maxLength: 100)
            FormField(label: "Country", text: $country, placeholder: "Country", maxLength: 100)
        }
        .onChange(of: city) { _, _ in checkForChanges() }
        .onChange(of: state) { _, _ in checkForChanges() }
        .onChange(of: country) { _, _ in checkForChanges() }
    }

    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Birthday", icon: AppIcons.calendar)

            Button {
                showDatePicker.toggle()
            } label: {
                HStack {
                    Text(dateOfBirth.map { formatDOBDisplay($0) } ?? "Not set")
                        .foregroundStyle(dateOfBirth == nil ? Color.secondary : Color.primary)
                    Spacer()
                    Image(systemName: AppIcons.chevronDown)
                        .foregroundStyle(Color.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if showDatePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())! },
                        set: { dateOfBirth = $0; checkForChanges() }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.brand)
                .onChange(of: dateOfBirth) { _, _ in checkForChanges() }
            }
        }
    }


    // MARK: - Actions

    private func loadUserData() {
        guard let user = authService.currentUser else { return }
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        bio = user.bio ?? ""
        city = user.city ?? ""
        state = user.state ?? ""
        country = user.country ?? ""
        // Parse DOB from YYYY-MM-DD
        if let dobString = user.dateOfBirth {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            dateOfBirth = fmt.date(from: dobString)
        }
    }

    private func checkForChanges() {
        guard let user = authService.currentUser else { return }
        // Compare DOB as YYYY-MM-DD string
        let currentDOB: String? = dateOfBirth.map {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: $0)
        }
        hasChanges = firstName != (user.firstName ?? "")
            || lastName != (user.lastName ?? "")
            || bio != (user.bio ?? "")
            || city != (user.city ?? "")
            || state != (user.state ?? "")
            || country != (user.country ?? "")
            || currentDOB != user.dateOfBirth
    }

    private func saveProfile() async {
        // Encode DOB as YYYY-MM-DD string
        let dobString: String? = dateOfBirth.map {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: $0)
        }
        // Sanitize: strip URLs from free-text fields (matches server-side sanitizeUserInput)
        let request = ProfileUpdateRequest(
            firstName: firstName.isEmpty ? nil : stripURLs(firstName),
            lastName: lastName.isEmpty ? nil : stripURLs(lastName),
            dateOfBirth: dobString,
            bio: bio.isEmpty ? nil : stripURLs(bio),
            city: city.isEmpty ? nil : stripURLs(city),
            state: state.isEmpty ? nil : stripURLs(state),
            country: country.isEmpty ? nil : stripURLs(country)
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

    /// Strip URLs from user input to prevent link injection.
    /// Matches the server-side sanitizeUserInput() behavior.
    private func stripURLs(_ text: String) -> String {
        let pattern = #"https?://\S+"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDOBDisplay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func uploadAvatar(_ image: UIImage) async {
        do {
            _ = try await userService.uploadAvatar(image: image)
            await authService.fetchCurrentUser()
            selectedAvatarImage = nil
            let status = "Profile photo updated."
            imageUploadStatus = status
            announceImageStatus(status)
        } catch {
            imageUploadStatus = "Profile photo upload failed. Choose a photo to try again."
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func uploadBanner(_ image: UIImage) async {
        do {
            _ = try await userService.uploadBanner(image: image)
            await authService.fetchCurrentUser()
            selectedBannerImage = nil
            let status = "Profile banner updated."
            imageUploadStatus = status
            announceImageStatus(status)
        } catch {
            imageUploadStatus = "Profile banner upload failed. Choose an image to try again."
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func loadSelectedImage(from item: PhotosPickerItem, isAvatar: Bool) async {
        defer {
            if isAvatar {
                selectedAvatarItem = nil
            } else {
                selectedBannerItem = nil
            }
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                showPhotoSelectionError()
                return
            }

            if isAvatar {
                selectedAvatarImage = image
            } else {
                selectedBannerImage = image
            }
        } catch {
            showPhotoSelectionError()
        }
    }

    private func showPhotoSelectionError() {
        imageUploadStatus = "Selected photo could not be loaded."
        errorText = "The selected photo could not be loaded. Please choose another photo."
        showingError = true
    }

    private func announceImageStatus(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private var imageUploadProgressValue: String {
        "\(Int(userService.uploadProgress * 100)) percent"
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

    private struct ProfileImagePickerPresentation: ViewModifier {
        @Binding var showingAvatarPicker: Bool
        @Binding var selectedAvatarItem: PhotosPickerItem?
        @Binding var showingBannerPicker: Bool
        @Binding var selectedBannerItem: PhotosPickerItem?

        func body(content: Content) -> some View {
            content
                .photosPicker(
                    isPresented: $showingAvatarPicker,
                    selection: $selectedAvatarItem,
                    matching: .images
                )
                .photosPicker(
                    isPresented: $showingBannerPicker,
                    selection: $selectedBannerItem,
                    matching: .images
                )
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthService())
    }
}
