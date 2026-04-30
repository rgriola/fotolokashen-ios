import SwiftUI

/// Preferences — language, timezone, and email notification settings.
/// Profile → App Settings → Preferences
struct PreferencesView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var userService = UserService.shared

    @State private var language = ""
    @State private var timezone = ""
    @State private var emailNotifications = true
    @State private var hasChanges = false
    @State private var showingError = false
    @State private var errorText = ""
    @State private var showingSaved = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Language", systemImage: "globe")
                    Spacer()
                    TextField("en", text: $language)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 80)
                }
                .onChange(of: language) { _, _ in checkForChanges() }

                HStack {
                    Label("Timezone", systemImage: "clock")
                    Spacer()
                    TextField("America/New_York", text: $timezone)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 180)
                }
                .onChange(of: timezone) { _, _ in checkForChanges() }

                Toggle(isOn: $emailNotifications) {
                    Label("Email Notifications", systemImage: "envelope")
                }
                .tint(.brand)
                .onChange(of: emailNotifications) { _, _ in checkForChanges() }

            } header: {
                Text("App Preferences")
            } footer: {
                Text("Language and timezone affect how content is displayed.")
            }
        }
        .navigationTitle("Preferences")
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
        .alert("Saved", isPresented: $showingSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your preferences have been updated.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    // MARK: - Actions

    private func loadData() {
        guard let user = authService.currentUser else { return }
        language = user.language ?? ""
        timezone = user.timezone ?? ""
        emailNotifications = user.emailNotifications ?? true
    }

    private func checkForChanges() {
        guard let user = authService.currentUser else { return }
        hasChanges = language != (user.language ?? "")
            || timezone != (user.timezone ?? "")
            || emailNotifications != (user.emailNotifications ?? true)
    }

    private func savePreferences() async {
        // Only send the fields this view manages — not the entire profile.
        // Sending all fields risked overwriting concurrent edits from other devices.
        let request = ProfileUpdateRequest(
            language: language.isEmpty ? nil : language,
            timezone: timezone.isEmpty ? nil : timezone,
            emailNotifications: emailNotifications
        )
        do {
            let updated = try await userService.updateProfile(request)
            authService.currentUser = updated
            hasChanges = false
            showingSaved = true
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
            .environmentObject(AuthService())
    }
}
