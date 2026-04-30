import SwiftUI

/// Privacy Settings — controls who can see the user's profile, locations, and social activity.
/// Profile → Privacy Settings
struct PrivacySettingsView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared

    @State private var profileVisibility = "public"
    @State private var showInSearch = true
    @State private var showLocation = true
    @State private var showSavedLocations = "public"
    @State private var allowFollowRequests = true

    @State private var hasChanges = false
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorText = ""

    private let visibilityOptions = ["public", "followers", "private"]

    var body: some View {
        Form {
            Section {
                Picker("Profile Visibility", selection: $profileVisibility) {
                    ForEach(visibilityOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }

                Toggle("Appear in People Search", isOn: $showInSearch)
                    .tint(.brand)

                Toggle("Show Location on Profile", isOn: $showLocation)
                    .tint(.brand)

                Picker("Saved Locations Visibility", selection: $showSavedLocations) {
                    ForEach(visibilityOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }

                Toggle("Allow Follow Requests", isOn: $allowFollowRequests)
                    .tint(.brand)

            } header: {
                Text("Visibility")
            } footer: {
                Text("Control who can see your profile, locations, and send follow requests.")
            }
            .onChange(of: profileVisibility) { _, _ in checkForChanges() }
            .onChange(of: showInSearch) { _, _ in checkForChanges() }
            .onChange(of: showLocation) { _, _ in checkForChanges() }
            .onChange(of: showSavedLocations) { _, _ in checkForChanges() }
            .onChange(of: allowFollowRequests) { _, _ in checkForChanges() }
        }
        .navigationTitle("Privacy Settings")
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
    }

    // MARK: - Actions

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
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
            .environmentObject(AuthService())
    }
}
