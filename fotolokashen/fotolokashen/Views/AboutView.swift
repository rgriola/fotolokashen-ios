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

                // Privacy Policy and Terms of Service Icons appear Black rather than brand color.
                NavigationLink {
                    LicensesView()
                } label: {
                    Label("Licenses & Acknowledgements", systemImage: AppIcons.documentText)
                }
                Link(destination: URL(string: "\(ConfigLoader.shared.backendBaseURL)/privacy-policy")!) {
                    Label("Privacy Policy", systemImage: AppIcons.handRaisedFill)
                        .foregroundStyle(Color.primary)
                }
                Link(destination: URL(string: "\(ConfigLoader.shared.backendBaseURL)/terms")!) {
                    Label("Terms of Service", systemImage: AppIcons.documentTextFill)
                        .foregroundStyle(Color.primary)
                }
            }

            // ── Credits ───────────────────────────────────────────────────
            Section {
                VStack(spacing: 8) {
                    Image(systemName: AppIcons.mappinAndEllipse)
                        .font(.largeTitle)
                        .foregroundStyle(Color.brand)
                    Text("fotolokashen")
                        .font(.headline)
                    Text("v\(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Text("© \(currentYear) Sea Lion Media LLC. All rights reserved.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
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
