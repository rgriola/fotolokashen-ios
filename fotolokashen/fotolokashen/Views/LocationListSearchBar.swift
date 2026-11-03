import SwiftUI

/// Search field with the sort menu on its trailing side for the My Spots list.
struct LocationListSearchBar: View {
    @Binding var searchText: String
    @Binding var sortOption: SortOption

    var body: some View {
        HStack(spacing: 12) {
            searchField
            sortMenu
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: AppIcons.search)
                .foregroundStyle(Color(.darkGray))
                .accessibilityHidden(true)
            // The field background is always white so black text stays readable in Dark Mode.
            TextField(
                "Search My Spots",
                text: $searchText,
                prompt: Text("Search My Spots").foregroundStyle(Color(.darkGray))
            )
            .foregroundStyle(Color.black)
            .tint(Color.black)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: AppIcons.closeCircle)
                        .foregroundStyle(Color(.darkGray))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(Color.white, in: Capsule())
        .overlay(Capsule().strokeBorder(Color(.systemGray4)))
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                Label("Newest First", systemImage: AppIcons.calendarBadgeClock)
                    .tag(SortOption.dateNewest)
                Label("Oldest First", systemImage: AppIcons.calendar)
                    .tag(SortOption.dateOldest)
                Label("Name A-Z", systemImage: AppIcons.textformatAbc)
                    .tag(SortOption.nameAZ)
                Label("Name Z-A", systemImage: AppIcons.textformatAbc)
                    .tag(SortOption.nameZA)
            }
        } label: {
            Image(systemName: AppIcons.arrowUpArrowDown)
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort Locations")
    }
}
