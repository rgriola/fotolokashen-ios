import SwiftUI

/// About — app version, build, and info links.
/// Profile → Support → About
struct AboutView: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        Form {
            // ── App Info ──────────────────────────────────────────────────
            Section("App Info") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
            }

            // ── Links ─────────────────────────────────────────────────────
            Section("Legal") {
                Link(destination: URL(string: "\(ConfigLoader.shared.backendBaseURL)/privacy-policy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .foregroundStyle(.primary)
                }
                Link(destination: URL(string: "\(ConfigLoader.shared.backendBaseURL)/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                        .foregroundStyle(.primary)
                }
            }

            // ── Credits ───────────────────────────────────────────────────
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPurple)
                    Text("fotolokashen")
                        .font(.headline)
                    Text("v\(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("© \(currentYear) fotolokashen. All rights reserved.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
