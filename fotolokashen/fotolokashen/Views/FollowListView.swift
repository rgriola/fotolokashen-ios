import SwiftUI
import Kingfisher

/// Reusable view for displaying followers or following list with pagination
struct FollowListView: View {
    let username: String
    let mode: FollowListMode

    @ObservedObject private var followService = FollowService.shared
    @State private var users: [FollowListUser] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var totalCount = 0
    @State private var errorMessage: String?

    enum FollowListMode {
        case followers
        case following
    }

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if users.isEmpty {
                emptyState
            } else {
                userList
            }
        }
        .task {
            await loadInitial()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: mode == .followers ? "person.2.slash" : "person.2")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(mode == .followers ? "No followers yet" : "Not following anyone")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(mode == .followers
                 ? "@\(username) doesn't have any followers yet."
                 : "@\(username) isn't following anyone yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - User List

    private var userList: some View {
        List {
            ForEach(users) { user in
                NavigationLink(value: user.username) {
                    UserRowView(user: user)
                }
            }

            // Load more indicator
            if hasMore {
                HStack {
                    Spacer()
                    if isLoadingMore {
                        ProgressView()
                    } else {
                        Button("Load More") {
                            Task {
                                await loadMore()
                            }
                        }
                        .foregroundColor(.brandPurple)
                    }
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .onAppear {
                    Task {
                        await loadMore()
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: String.self) { selectedUsername in
            PublicProfileView(username: selectedUsername)
        }
    }

    // MARK: - Actions

    private func loadInitial() async {
        isLoading = true
        currentPage = 1
        users = []

        do {
            let result = try await fetchPage(page: 1)
            users = result.users
            hasMore = result.hasMore
            totalCount = result.total
            currentPage = 1
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true

        let nextPage = currentPage + 1

        do {
            let result = try await fetchPage(page: nextPage)
            users.append(contentsOf: result.users)
            hasMore = result.hasMore
            totalCount = result.total
            currentPage = nextPage
        } catch {
            #if DEBUG
            if ConfigLoader.shared.enableDebugLogging {
                print("[FollowListView] Load more failed: \(error)")
            }
            #endif
        }

        isLoadingMore = false
    }

    private func fetchPage(page: Int) async throws -> (users: [FollowListUser], hasMore: Bool, total: Int) {
        switch mode {
        case .followers:
            let response = try await followService.getFollowers(username: username, page: page)
            return (response.followers, response.pagination.hasMore, response.pagination.total)
        case .following:
            let response = try await followService.getFollowing(username: username, page: page)
            return (response.following, response.pagination.hasMore, response.pagination.total)
        }
    }
}

// MARK: - User Row View

struct UserRowView: View {
    let user: FollowListUser

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = user.avatarURL {
                KFImage(avatarURL)
                    .resizable()
                    .placeholder {
                        avatarPlaceholder
                    }
                    .onFailureImage(nil)
                    .fade(duration: 0.2)
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            // User info
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
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brandPurple.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(user.initials)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.brandPurple)
            )
    }
}
