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
                ChangeEmailView()
                    .environmentObject(authService)
            } label: {
                Label("Change Email", systemImage: "envelope.fill")
            }

            NavigationLink {
                ChangeUsernameView()
                    .environmentObject(authService)
            } label: {
                Label("Change Username", systemImage: "at")
            }

            NavigationLink {
                ChangePasswordView()
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

// MARK: - Change Password

private struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    // Validation (mirrors backend Zod schema exactly)
    private var hasMinLength: Bool { newPassword.count >= 8 }
    private var hasUppercase: Bool { newPassword.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var hasLowercase: Bool { newPassword.range(of: "[a-z]", options: .regularExpression) != nil }
    private var hasNumber: Bool { newPassword.range(of: "[0-9]", options: .regularExpression) != nil }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && newPassword == confirmPassword }
    private var isDifferentFromCurrent: Bool { !newPassword.isEmpty && newPassword != currentPassword }
    private var isFormValid: Bool {
        !currentPassword.isEmpty && hasMinLength && hasUppercase &&
        hasLowercase && hasNumber && passwordsMatch && isDifferentFromCurrent
    }

    var body: some View {
        Form {
            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
            } header: {
                Text("Verify Identity")
            }

            Section {
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)

                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            } header: {
                Text("New Password")
            } footer: {
                if !newPassword.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        validationRow("At least 8 characters", met: hasMinLength)
                        validationRow("One uppercase letter", met: hasUppercase)
                        validationRow("One lowercase letter", met: hasLowercase)
                        validationRow("One number", met: hasNumber)
                        validationRow("Different from current", met: isDifferentFromCurrent)
                        if !confirmPassword.isEmpty {
                            validationRow("Passwords match", met: passwordsMatch)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button {
                    Task { await changePassword() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Saving…")
                        } else {
                            Text("Change Password")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || isLoading)
            } footer: {
                Text("You will be logged out of all devices after changing your password.")
                    .font(.caption)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Password Changed", isPresented: $showingSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been changed. You will need to log in again.")
        }
    }

    private func validationRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }

    private func changePassword() async {
        isLoading = true
        errorMessage = nil

        do {
            let request = ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmPassword: confirmPassword
            )
            let _: SuccessResponse = try await APIClient.shared.post(
                "/api/auth/change-password",
                body: request
            )
            showingSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
    let confirmPassword: String
}

// MARK: - Change Username

private struct ChangeUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var newUsername = ""
    @State private var currentPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    // Validation (mirrors backend Zod + regex)
    private let usernameRegex = /^[a-zA-Z0-9_-]{3,50}$/
    private let reservedUsernames: Set<String> = [
        "admin", "api", "app", "auth", "blog", "help", "login", "logout",
        "map", "profile", "register", "settings", "teams", "verify-email",
        "reset-password", "forgot-password", "share", "support", "contact",
        "about", "privacy", "terms", "legal", "security", "status"
    ]

    private var isValidFormat: Bool {
        newUsername.wholeMatch(of: usernameRegex) != nil
    }
    private var isNotReserved: Bool {
        !reservedUsernames.contains(newUsername.lowercased())
    }
    private var isNotCurrent: Bool {
        guard let current = authService.currentUser?.username else { return true }
        return newUsername.lowercased() != current.lowercased()
    }
    private var isFormValid: Bool {
        isValidFormat && isNotReserved && isNotCurrent && !currentPassword.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("New Username", text: $newUsername)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } header: {
                Text("New Username")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if !newUsername.isEmpty {
                        validationRow("3–50 characters", met: newUsername.count >= 3 && newUsername.count <= 50)
                        validationRow("Letters, numbers, hyphens, underscores only", met: isValidFormat || newUsername.count < 3)
                        if !isNotReserved {
                            validationRow("Not a reserved name", met: false)
                        }
                        if !isNotCurrent {
                            validationRow("Different from current username", met: false)
                        }
                    }
                    Text("You can change your username once per 30 days (max 3 per year).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
            } header: {
                Text("Verify Identity")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button {
                    Task { await changeUsername() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Saving…")
                        } else {
                            Text("Change Username")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || isLoading)
            }
        }
        .navigationTitle("Change Username")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Username Changed", isPresented: $showingSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your username has been updated to @\(newUsername.lowercased()).")
        }
    }

    private func validationRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }

    private func changeUsername() async {
        isLoading = true
        errorMessage = nil

        do {
            let request = ChangeUsernameRequest(
                newUsername: newUsername.lowercased().trimmingCharacters(in: .whitespaces),
                currentPassword: currentPassword
            )
            let _: ChangeUsernameResponse = try await APIClient.shared.post(
                "/api/auth/change-username",
                body: request
            )

            // Refresh the cached user so the UI updates immediately
            if let updated = try? await APIClient.shared.getCurrentUser() {
                authService.currentUser = updated
            }

            showingSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct ChangeUsernameRequest: Codable {
    let newUsername: String
    let currentPassword: String
}

private struct ChangeUsernameResponse: Codable {
    let success: Bool?
    let message: String?
    let username: String?
}

// MARK: - Change Email

private struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var newEmail = ""
    @State private var currentPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    // Validation
    private var isValidEmail: Bool {
        let emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return newEmail.wholeMatch(of: emailRegex) != nil
    }
    private var isNotCurrent: Bool {
        guard let current = authService.currentUser?.email else { return true }
        return newEmail.lowercased() != current.lowercased()
    }
    private var isFormValid: Bool {
        isValidEmail && isNotCurrent && newEmail.count <= 255 && !currentPassword.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("New Email Address", text: $newEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } header: {
                Text("New Email")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if !newEmail.isEmpty {
                        if !isValidEmail {
                            validationRow("Valid email address", met: false)
                        }
                        if !isNotCurrent {
                            validationRow("Different from current email", met: false)
                        }
                    }
                    Text("A verification link will be sent to your new email. Your current email will receive a notification with an option to cancel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
            } header: {
                Text("Verify Identity")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button {
                    Task { await requestEmailChange() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Sending…")
                        } else {
                            Text("Send Verification Email")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || isLoading)
            } footer: {
                Text("You can change your email once per 24 hours (max 5 per year).")
                    .font(.caption)
            }
        }
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Verification Sent", isPresented: $showingSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Check your new email address for a verification link. The change won't take effect until you confirm.")
        }
    }

    private func validationRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
        }
    }

    private func requestEmailChange() async {
        isLoading = true
        errorMessage = nil

        do {
            let request = ChangeEmailRequest(
                newEmail: newEmail.lowercased().trimmingCharacters(in: .whitespaces),
                currentPassword: currentPassword
            )
            let _: SuccessResponse = try await APIClient.shared.post(
                "/api/auth/change-email/request",
                body: request
            )
            showingSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct ChangeEmailRequest: Codable {
    let newEmail: String
    let currentPassword: String
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
