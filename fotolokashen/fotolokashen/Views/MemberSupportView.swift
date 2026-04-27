import SwiftUI

/// Native iOS support request form for authenticated users.
/// Calls POST /api/member-support — same endpoint as the web app.
/// Profile → Support → Contact Support
struct MemberSupportView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    // Validation (mirrors backend VALIDATION constants)
    private var isSubjectValid: Bool { subject.trimmingCharacters(in: .whitespaces).count >= 5 }
    private var isMessageValid: Bool { message.trimmingCharacters(in: .whitespaces).count >= 10 }
    private var isFormValid: Bool { isSubjectValid && isMessageValid }

    var body: some View {
        Form {
            // ── Your Info (auto-filled, read-only) ─────────────────────
            Section {
                if let user = authService.currentUser {
                    LabeledContent("Name", value: user.fullName ?? user.username)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Username", value: "@\(user.username)")
                }
            } header: {
                Text("Your Information")
            } footer: {
                Text("This info is included with your support request.")
                    .font(.caption)
            }

            // ── Subject ────────────────────────────────────────────────
            Section {
                TextField("Brief description of your issue", text: $subject)
                    .autocapitalization(.sentences)
            } header: {
                Text("Subject")
            } footer: {
                HStack {
                    if !subject.isEmpty && !isSubjectValid {
                        Text("At least 5 characters")
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Text("\(subject.count) / 200")
                        .foregroundStyle(subject.count > 200 ? .red : .secondary)
                }
                .font(.caption)
            }
            .onChange(of: subject) { _, newValue in
                if newValue.count > 200 {
                    subject = String(newValue.prefix(200))
                }
            }

            // ── Message ────────────────────────────────────────────────
            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 150)
            } header: {
                Text("Message")
            } footer: {
                HStack {
                    if !message.isEmpty && !isMessageValid {
                        Text("At least 10 characters")
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Text("\(message.count) / 2000")
                        .foregroundStyle(message.count > 2000 ? .red : .secondary)
                }
                .font(.caption)
            }
            .onChange(of: message) { _, newValue in
                if newValue.count > 2000 {
                    message = String(newValue.prefix(2000))
                }
            }

            // ── Error ──────────────────────────────────────────────────
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            // ── Submit ─────────────────────────────────────────────────
            Section {
                Button {
                    Task { await submitSupportRequest() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Sending…")
                        } else {
                            Image(systemName: "paperplane.fill")
                                .padding(.trailing, 4)
                            Text("Send Support Request")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isFormValid || isLoading || subject.count > 200 || message.count > 2000)
            } footer: {
                Text("We typically respond within 24–48 hours.")
                    .font(.caption)
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Message Sent", isPresented: $showingSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your support request has been sent. Check your email for confirmation.")
        }
    }

    // MARK: - API Call

    private func submitSupportRequest() async {
        guard let user = authService.currentUser else { return }

        isLoading = true
        errorMessage = nil

        do {
            let request = SupportRequest(
                name: user.fullName ?? user.username,
                email: user.email,
                subject: subject.trimmingCharacters(in: .whitespaces),
                message: message.trimmingCharacters(in: .whitespaces)
            )

            let _: SupportResponse = try await APIClient.shared.post(
                "/api/member-support",
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

// MARK: - Request / Response

private struct SupportRequest: Codable {
    let name: String
    let email: String
    let subject: String
    let message: String
}

private struct SupportResponse: Codable {
    let success: Bool?
    let message: String?
}
