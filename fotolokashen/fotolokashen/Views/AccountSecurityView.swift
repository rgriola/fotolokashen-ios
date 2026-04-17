import SwiftUI

/// Account & Security — email, username, password, and Danger Zone (Delete Account).
/// Replaces the old SettingsView as the security-focused subview.
/// Profile → Account & Security
struct AccountSecurityView: View {
    @EnvironmentObject var authService: AuthService

    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showingError = false
    @State private var errorText = ""

    var body: some View {
        Form {
            // ── Personal Details ──────────────────────────────────────────
            personalDetailsSection

            // ── Security ──────────────────────────────────────────────────
            securitySection

            // ── Danger Zone ───────────────────────────────────────────────
            dangerZoneSection
        }
        .navigationTitle("Account & Security")
        .navigationBarTitleDisplayMode(.inline)
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
                    DetailRow(label: "Email", value: user.email)

                    // City / State / Country
                    let locationParts = [user.city, user.state, user.country]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                    if !locationParts.isEmpty {
                        DetailRow(label: "Location", value: locationParts.joined(separator: ", "))
                    }

                    // Date of birth
                    if let dob = user.dateOfBirth {
                        DetailRow(label: "Birthday", value: formatDateOfBirth(dob))
                    }

                    Divider()

                    // Joined date
                    DetailRow(label: "Joined", value: formatDate(user.createdAt))
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

// MARK: - Detail Row

private struct DetailRow: View {
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
