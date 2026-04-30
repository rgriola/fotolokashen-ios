import SwiftUI

/// Notification Preferences — email and push notification toggles.
/// Profile → Notification Preferences
struct NotificationPreferencesView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared

    @State private var emailNotifications = true
    @State private var hasChanges = false
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorText = ""

    var body: some View {
        Form {
            Section {
                Toggle("Email Notifications", isOn: $emailNotifications)
                    .tint(.brand)
                    .onChange(of: emailNotifications) { _, _ in checkForChanges() }
            } header: {
                Text("Email")
            } footer: {
                Text("Receive emails for new followers, location activity, and account updates.")
            }

            // Future: push notifications section
            Section {
                HStack {
                    Label("Push Notifications", systemImage: "bell.badge")
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Push")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if hasChanges {
                    Button("Save") {
                        Task { await savePreferences() }
                    }
                    .fontWeight(.semibold)
                    .disabled(userService.isLoading)
                }
            }
        }
        .onAppear { loadData() }
        .alert("Saved", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Notification preferences updated.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    // MARK: - Actions

    private func loadData() {
        emailNotifications = authService.currentUser?.emailNotifications ?? true
    }

    private func checkForChanges() {
        hasChanges = emailNotifications != (authService.currentUser?.emailNotifications ?? true)
    }

    private func savePreferences() async {
        // Reuse profile update to save the emailNotifications flag
        let user = authService.currentUser
        let request = ProfileUpdateRequest(
            firstName: user?.firstName,
            lastName: user?.lastName,
            bio: user?.bio,
            city: user?.city,
            country: user?.country,
            language: user?.language,
            timezone: user?.timezone,
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
}

#Preview {
    NavigationStack {
        NotificationPreferencesView()
            .environmentObject(AuthService())
    }
}
