import SwiftUI

/// Settings view with privacy controls and account info
/// Matches web app's /profile Privacy tab functionality
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared

    // Privacy fields
    @State private var profileVisibility = "public"
    @State private var showInSearch = true
    @State private var showLocation = true
    @State private var showSavedLocations = "public"
    @State private var allowFollowRequests = true

    // UI state
    @State private var hasChanges = false
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorText = ""
    @State private var showingLogoutConfirmation = false

    private let visibilityOptions = ["public", "followers", "private"]

    var body: some View {
        NavigationStack {
            Form {
                // Account info (read-only)
                accountSection

                // Privacy settings
                privacySection

                // App info
                appInfoSection

                // Logout
                logoutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasChanges {
                        Button("Save") {
                            Task { await savePrivacy() }
                        }
                        .fontWeight(.semibold)
                        .disabled(userService.isLoading)
                    }
                }
            }
            .onAppear { loadPrivacyData() }
            .alert("Settings Saved", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your privacy settings have been updated.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    Task {
                        LocationStore.shared.clear()
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            if let user = authService.currentUser {
                LabeledContent("Username", value: user.username)
                LabeledContent("Email", value: user.email)
                LabeledContent("Member since", value: formatDate(user.createdAt))
            }
        }
    }

    private var privacySection: some View {
        Section {
            // Profile visibility
            Picker("Profile Visibility", selection: $profileVisibility) {
                ForEach(visibilityOptions, id: \.self) { option in
                    Text(option.capitalized).tag(option)
                }
            }

            // Show in search
            Toggle("Appear in People Search", isOn: $showInSearch)
                .tint(.brandPurple)

            // Show location
            Toggle("Show Location on Profile", isOn: $showLocation)
                .tint(.brandPurple)

            // Saved locations visibility
            Picker("Saved Locations Visibility", selection: $showSavedLocations) {
                ForEach(visibilityOptions, id: \.self) { option in
                    Text(option.capitalized).tag(option)
                }
            }

            // Follow requests
            Toggle("Allow Follow Requests", isOn: $allowFollowRequests)
                .tint(.brandPurple)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Control who can see your profile, locations, and send follow requests.")
                .font(.caption)
        }
        .onChange(of: profileVisibility) { _ in checkForChanges() }
        .onChange(of: showInSearch) { _ in checkForChanges() }
        .onChange(of: showLocation) { _ in checkForChanges() }
        .onChange(of: showSavedLocations) { _ in checkForChanges() }
        .onChange(of: allowFollowRequests) { _ in checkForChanges() }
    }

    private var appInfoSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)

            NavigationLink {
                // Privacy policy / terms web view placeholder
                Text("Terms of Service")
                    .navigationTitle("Terms")
            } label: {
                Text("Terms of Service")
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showingLogoutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadPrivacyData() {
        guard let user = authService.currentUser else { return }
        profileVisibility = user.profileVisibility ?? "public"
        showInSearch = user.showInSearch ?? true
        showLocation = user.showLocation ?? true
        showSavedLocations = user.showSavedLocations ?? "public"
        allowFollowRequests = user.allowFollowRequests ?? true
    }

    private func checkForChanges() {
        guard let user = authService.currentUser else { return }
        hasChanges = profileVisibility != (user.profileVisibility ?? "public")
            || showInSearch != (user.showInSearch ?? true)
            || showLocation != (user.showLocation ?? true)
            || showSavedLocations != (user.showSavedLocations ?? "public")
            || allowFollowRequests != (user.allowFollowRequests ?? true)
    }

    private func savePrivacy() async {
        let request = PrivacyUpdateRequest(
            profileVisibility: profileVisibility,
            showInSearch: showInSearch,
            showLocation: showLocation,
            showSavedLocations: showSavedLocations,
            allowFollowRequests: allowFollowRequests
        )

        do {
            let updatedUser = try await userService.updatePrivacy(request)
            authService.currentUser = updatedUser
            hasChanges = false
            showingSaveSuccess = true
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }

    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return dateString }
            return formatOutput(date)
        }
        return formatOutput(date)
    }

    private func formatOutput(_ date: Date) -> String {
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
}
