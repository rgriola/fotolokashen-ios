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
                Image(systemName: AppIcons.search)
                    .foregroundStyle(Color.secondary)

                TextField("Search by username, name, or city...", text: $searchText)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.none)
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
                        Image(systemName: AppIcons.closeCircle)
                            .foregroundStyle(Color.secondary)
                    }
                    .accessibilityLabel("Clear people search")
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
                    Image(systemName: AppIcons.personSlash)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.secondary)
                    Text("No users found")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: AppIcons.peopleCircle)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.secondary)
                    Text("Find People")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Text("Search by username, name, or city")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
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
            searchResults = response.results
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                dlog("DiscoverTab", "User search failed")
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
                    .foregroundStyle(Color.secondary)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                if let location = user.locationString, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcons.mappin)
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            Image(systemName: AppIcons.forward)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brand.opacity(0.2))
            .frame(width: 48, height: 48)
            .overlay(
                Text(user.initials)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brand)
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
                    Image(systemName: AppIcons.people)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.secondary)
                    Text("Not following anyone yet")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Text("Discover people to follow in the Discover tab")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
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
                dlog("MyFollowingTab", "Following list load failed")
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
                dlog("MyFollowingTab", "Following list pagination failed")
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
                    Image(systemName: AppIcons.peopleSlash)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.secondary)
                    Text("No followers yet")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                    Text("Share your profile to get followers")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
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
                dlog("MyFollowersTab", "Followers list load failed")
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
                dlog("MyFollowersTab", "Followers list pagination failed")
            }
            #endif
        }
    }
}
