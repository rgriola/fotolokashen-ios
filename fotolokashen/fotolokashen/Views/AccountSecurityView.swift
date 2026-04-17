import SwiftUI
import CoreLocation
import AVFoundation
import Photos
import UserNotifications

/// Account & Security — email, username, password, and Danger Zone (Delete Account).
/// Replaces the old SettingsView as the security-focused subview.
/// Profile → Account & Security
struct AccountSecurityView: View {
    @EnvironmentObject var authService: AuthService

    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showingError = false
    @State private var errorText = ""

    // Preferences
    @ObservedObject private var userService = UserService.shared
    @State private var language = ""
    @State private var timezone = ""
    @State private var emailNotifications = true
    @State private var prefHasChanges = false
    @State private var showingPrefSaved = false

    // Permissions (read from iOS, open Settings for changes)
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var photoStatus: PHAuthorizationStatus = .notDetermined
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            // ── Personal Details ──────────────────────────────────────────
            personalDetailsSection

            // ── Security ──────────────────────────────────────────────────
            securitySection

            // ── Preferences ───────────────────────────────────────────────
            preferencesSection

            // ── Permissions ───────────────────────────────────────────────
            permissionsSection

            // ── Danger Zone ───────────────────────────────────────────────
            dangerZoneSection
        }
        .navigationTitle("Account & Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPreferences()
            refreshPermissions()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if prefHasChanges {
                    Button("Save") {
                        Task { await savePreferences() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Your account, all locations, photos, and data will be permanently removed. This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var personalDetailsSection: some View {
        Section("Personal Details") {
            if let user = authService.currentUser {
                VStack(alignment: .leading, spacing: 10) {
                    // Name + Username
                    if let name = user.fullName {
                        Text(name)
                            .font(.headline)
                    }
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    // Email
                    ProfileDetailRow(label: "Email", value: user.email)

                    // City / State / Country
                    let locationParts = [user.city, user.state, user.country]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                    if !locationParts.isEmpty {
                        ProfileDetailRow(label: "Location", value: locationParts.joined(separator: ", "))
                    }
                    
                    // Date of birth
                    if let dob = user.dateOfBirth {
                        ProfileDetailRow(label: "Birthday", value: formatDateOfBirth(dob))
                    }

                    Divider()

                    // Joined date
                    ProfileDetailRow(label: "Joined", value: formatDate(user.createdAt))
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            NavigationLink {
                EditProfileView()
            } label: {
                Label("Edit Profile", systemImage: "person.fill")
            }

            NavigationLink {
                ChangeEmailPlaceholderView()
            } label: {
                Label("Change Email", systemImage: "envelope.fill")
            }

            NavigationLink {
                ChangeUsernamePlaceholderView()
            } label: {
                Label("Change Username", systemImage: "at")
            }

            NavigationLink {
                ChangePasswordPlaceholderView()
            } label: {
                Label("Change Password", systemImage: "key.fill")
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            HStack {
                Label("Language", systemImage: "globe")
                Spacer()
                TextField("en", text: $language)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 80)
            }
            .onChange(of: language) { _, _ in checkPrefChanges() }

            HStack {
                Label("Timezone", systemImage: "clock")
                Spacer()
                TextField("America/New_York", text: $timezone)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 180)
            }
            .onChange(of: timezone) { _, _ in checkPrefChanges() }

            Toggle(isOn: $emailNotifications) {
                Label("Email Notifications", systemImage: "envelope")
            }
            .tint(.brandPurple)
            .onChange(of: emailNotifications) { _, _ in checkPrefChanges() }
        }
    }

    private var permissionsSection: some View {
        Section {
            PermissionRow(
                icon: "location.fill",
                label: "Location (GPS)",
                isGranted: locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
            )
            PermissionRow(
                icon: "camera.fill",
                label: "Camera",
                isGranted: cameraStatus == .authorized
            )
            PermissionRow(
                icon: "photo.fill",
                label: "Photo Library",
                isGranted: photoStatus == .authorized || photoStatus == .limited
            )
            PermissionRow(
                icon: "bell.fill",
                label: "Notifications",
                isGranted: notificationStatus == .authorized || notificationStatus == .provisional
            )
        } header: {
            Text("Permissions")
        } footer: {
            Text("Tap a permission to open iOS Settings and change it there.")
        }
    }

    // MARK: - Preferences Actions

    private func loadPreferences() {
        guard let user = authService.currentUser else { return }
        language = user.language ?? ""
        timezone = user.timezone ?? ""
        emailNotifications = user.emailNotifications ?? true
    }

    private func checkPrefChanges() {
        guard let user = authService.currentUser else { return }
        prefHasChanges = language != (user.language ?? "")
            || timezone != (user.timezone ?? "")
            || emailNotifications != (user.emailNotifications ?? true)
    }

    private func savePreferences() async {
        let user = authService.currentUser
        let request = ProfileUpdateRequest(
            firstName: user?.firstName,
            lastName: user?.lastName,
            dateOfBirth: user?.dateOfBirth,
            bio: user?.bio,
            city: user?.city,
            state: user?.state,
            country: user?.country,
            language: language.isEmpty ? nil : language,
            timezone: timezone.isEmpty ? nil : timezone,
            emailNotifications: emailNotifications
        )
        do {
            let updated = try await userService.updateProfile(request)
            authService.currentUser = updated
            prefHasChanges = false
            showingPrefSaved = true
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }

    // MARK: - Permissions

    private func refreshPermissions() {
        locationStatus = CLLocationManager().authorizationStatus
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run { notificationStatus = settings.authorizationStatus }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteAccountConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isDeletingAccount {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Deleting...")
                    } else {
                        Label("Delete Account", systemImage: "trash.fill")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(isDeletingAccount)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Permanently deletes your account and all associated data. This action cannot be undone.")
                .font(.caption)
        }
    }

    // MARK: - Actions

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await UserService.shared.deleteAccount()
            LocationStore.shared.clear()
            try? KeychainService.shared.clearTokens()
            authService.isAuthenticated = false
            authService.currentUser = nil
        } catch {
            isDeletingAccount = false
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return formatOutput(date) }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return formatOutput(date) }
        return dateString
    }

    private func formatDateOfBirth(_ dobString: String) -> String {
        // Input: YYYY-MM-DD
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dobString) else { return dobString }
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatOutput(_ date: Date) -> String {
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }
}

// MARK: - Placeholder subviews (wire these to existing web-backed forms)

private struct ChangeEmailPlaceholderView: View {
    var body: some View {
        Text("Change Email")
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChangeUsernamePlaceholderView: View {
    var body: some View {
        Text("Change Username")
            .navigationTitle("Change Username")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChangePasswordPlaceholderView: View {
    var body: some View {
        Text("Change Password")
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let label: String
    let isGranted: Bool

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(isGranted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isGranted ? "On" : "Off")
                        .font(.subheadline)
                        .foregroundStyle(isGranted ? .green : .red)
                }
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Profile Detail Row


private struct ProfileDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        AccountSecurityView()
            .environmentObject(AuthService())
    }
}
