import SwiftUI

/// Main Profile hub — shows user header, navigation menu, and logout.
/// Replaces the old dense edit-form approach with a clean list-style hub.
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    // Social stats
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showingLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // ── Header (avatar, name, stats) ──────────────────────────
                Section {
                    profileHeaderRow
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // ── App Settings ──────────────────────────────────────────
                Section("App Settings") {
                    NavigationLink {
                        AccountSecurityView()
                    } label: {
                        Label("Account & Security", systemImage: "lock.shield.fill")
                    }

                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Privacy Settings", systemImage: "eye.slash.fill")
                    }

                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        Label("Notification Preferences", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        PreferencesView()
                    } label: {
                        Label("Preferences", systemImage: "gearshape.fill")
                    }

                    NavigationLink {
                        PermissionsView()
                    } label: {
                        Label("Permissions", systemImage: "hand.raised.fill")
                    }
                }

                // ── Support ───────────────────────────────────────────────
                Section("Support") {
                    Link(destination: URL(string: "\(ConfigLoader.shared.backendBaseURL)/help")!) {
                        Label("Help & FAQ", systemImage: "questionmark.circle.fill")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle.fill")
                    }
                }

                // ── Logout ────────────────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadSocialStats() }
            .alert("Log Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    Task {
                        LocationStore.shared.clear()
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .sheet(isPresented: $showFollowers) {
                if let username = authService.currentUser?.username {
                    NavigationStack {
                        FollowListView(username: username, mode: .followers)
                            .navigationTitle("Followers")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showFollowers = false }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showFollowing) {
                if let username = authService.currentUser?.username {
                    NavigationStack {
                        FollowListView(username: username, mode: .following)
                            .navigationTitle("Following")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showFollowing = false }
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Header Row

    private var profileHeaderRow: some View {
        VStack(spacing: 0) {
            // Banner + Avatar
            ZStack(alignment: .bottomLeading) {
                ProfileBannerView(
                    bannerURL: authService.currentUser?.bannerURL,
                    hasBannerImage: authService.currentUser?.bannerImage != nil
                )

                ProfileAvatarView(
                    avatarURL: authService.currentUser?.avatarURL,
                    initials: authService.currentUser?.initials ?? "?"
                )
                .offset(y: 24)
                .padding(.leading, 16)
            }
            .padding(.bottom, 28)

            // Name + Username
            if let user = authService.currentUser {
                VStack(spacing: 4) {
                    if let first = user.firstName, let last = user.lastName {
                        Text("\(first) \(last)")
                            .font(.title3)
                            .fontWeight(.bold)
                    } else if let first = user.firstName {
                        Text(first)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }

            // Stats bar
            HStack(spacing: 0) {
                Spacer()
                Button { showFollowers = true } label: {
                    ProfileStatItem(count: followersCount, label: "Followers")
                }
                .buttonStyle(.plain)
                Spacer()
                Divider().frame(height: 28)
                Spacer()
                Button { showFollowing = true } label: {
                    ProfileStatItem(count: followingCount, label: "Following")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 10)

            Divider()
        }
    }

    // MARK: - Helpers

    private func loadSocialStats() async {
        guard let username = authService.currentUser?.username else { return }
        do {
            async let fTask = FollowService.shared.getFollowers(username: username, page: 1, limit: 1)
            async let gTask = FollowService.shared.getFollowing(username: username, page: 1, limit: 1)
            let (fResp, gResp) = try await (fTask, gTask)
            followersCount = fResp.pagination.total
            followingCount = gResp.pagination.total
        } catch {
            #if DEBUG
            print("[ProfileView] Social stats error: \(error)")
            #endif
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
}
