import SwiftUI
import Kingfisher

/// People search and discovery view with tabs for Followers, Following, and Discover
///
// REVIEW: Architecture improvements:
// 1. SearchUserRow and UserRowView are nearly identical components — merge into one reusable view.
// 2. Three tab contents (DiscoverTab, MyFollowersTab, MyFollowingTab) are ~150 lines each —
//    extract to separate files to reduce this file from ~520 to ~200 lines.
// 3. No VoiceOver announcements when search results load or are empty.
struct PeopleSearchView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var followService = FollowService.shared
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Followers").tag(0)
                    Text("Following").tag(1)
                    Text("Discover").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Tab content
                switch selectedTab {
                case 0:
                    MyFollowersTab()
                case 1:
                    MyFollowingTab()
                case 2:
                    DiscoverTab()
                default:
                    EmptyView()
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Discover Tab

private struct DiscoverTab: View {
    @ObservedObject private var followService = FollowService.shared
    @State private var searchText = ""
    @State private var searchResults: [SearchUser] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search by username, name, or city...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { _, newValue in
                        // Debounced search
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            guard !Task.isCancelled else { return }
                            if newValue.count >= 2 {
                                await search(query: newValue)
                            } else if newValue.isEmpty {
                                searchResults = []
                                hasSearched = false
                            }
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Results
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && hasSearched {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No users found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Find People")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Search by username, name, or city")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(searchResults) { user in
                        NavigationLink(value: user.username) {
                            SearchUserRow(user: user)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: String.self) { username in
            PublicProfileView(username: username)
        }
    }

    private func search(query: String) async {
        guard query.count >= 2 else { return }
        isSearching = true
        hasSearched = true

        do {
            let response = try await followService.searchUsers(query: query)
            searchResults = response.users
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[DiscoverTab] Search failed: \(error)")
            }
            #endif
        }

        isSearching = false
    }
}

// MARK: - Search User Row

private struct SearchUserRow: View {
    let user: SearchUser

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = user.avatarURL {
                KFImage(avatarURL)
                    .resizable()
                    .placeholder {
                        avatarPlaceholder
                    }
                    .onFailureView {
                        EmptyView()
                    }
                    .fade(duration: 0.2)
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let location = user.locationString, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brandPurple.opacity(0.2))
            .frame(width: 48, height: 48)
            .overlay(
                Text(user.initials)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandPurple)
            )
    }
}

// MARK: - My Following Tab

private struct MyFollowingTab: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var followService = FollowService.shared
    @State private var users: [FollowListUser] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMore = true

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Not following anyone yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Discover people to follow in the Discover tab")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(users) { user in
                        NavigationLink(value: user.username) {
                            UserRowView(user: user)
                        }
                    }

                    if hasMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .onAppear {
                            Task { await loadMore() }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: String.self) { username in
            PublicProfileView(username: username)
        }
        .task {
            await loadInitial()
        }
    }

    private func loadInitial() async {
        guard let username = authService.currentUser?.username else { return }
        isLoading = true

        do {
            let response = try await followService.getFollowing(username: username, page: 1)
            users = response.following
            hasMore = response.pagination.hasMore
            currentPage = 1
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[MyFollowingTab] Load failed: \(error)")
            }
            #endif
        }

        isLoading = false
    }

    private func loadMore() async {
        guard let username = authService.currentUser?.username, hasMore else { return }
        let nextPage = currentPage + 1

        do {
            let response = try await followService.getFollowing(username: username, page: nextPage)
            users.append(contentsOf: response.following)
            hasMore = response.pagination.hasMore
            currentPage = nextPage
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[MyFollowingTab] Load more failed: \(error)")
            }
            #endif
        }
    }
}

// MARK: - My Followers Tab

private struct MyFollowersTab: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var followService = FollowService.shared
    @State private var users: [FollowListUser] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMore = true

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No followers yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Share your profile to get followers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(users) { user in
                        NavigationLink(value: user.username) {
                            UserRowView(user: user)
                        }
                    }

                    if hasMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .onAppear {
                            Task { await loadMore() }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: String.self) { username in
            PublicProfileView(username: username)
        }
        .task {
            await loadInitial()
        }
    }

    private func loadInitial() async {
        guard let username = authService.currentUser?.username else { return }
        isLoading = true

        do {
            let response = try await followService.getFollowers(username: username, page: 1)
            users = response.followers
            hasMore = response.pagination.hasMore
            currentPage = 1
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[MyFollowersTab] Load failed: \(error)")
            }
            #endif
        }

        isLoading = false
    }

    private func loadMore() async {
        guard let username = authService.currentUser?.username, hasMore else { return }
        let nextPage = currentPage + 1

        do {
            let response = try await followService.getFollowers(username: username, page: nextPage)
            users.append(contentsOf: response.followers)
            hasMore = response.pagination.hasMore
            currentPage = nextPage
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[MyFollowersTab] Load more failed: \(error)")
            }
            #endif
        }
    }
}
