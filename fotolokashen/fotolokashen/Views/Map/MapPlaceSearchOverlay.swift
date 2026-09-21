import SwiftUI
import MapKit

/// Floating search bar + suggestions list for searching Apple's map data (places,
/// addresses, POIs) on the Map tab — separate from LocationListView's saved-locations search.
struct MapPlaceSearchOverlay: View {
    @ObservedObject var searchService: MapPlaceSearchService
    @FocusState private var isSearchFieldFocused: Bool
    let onSelect: (MKLocalSearchCompletion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search Apple Maps", text: $searchService.queryFragment)
                    .focused($isSearchFieldFocused)
                    .accessibilityLabel("Search Apple Maps for a place or address")
                if !searchService.queryFragment.isEmpty {
                    Button {
                        searchService.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal)

            if !searchService.suggestions.isEmpty {
                List(searchService.suggestions, id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                        isSearchFieldFocused = false
                    } label: {
                        VStack(alignment: .leading) {
                            Text(suggestion.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(suggestion.title), \(suggestion.subtitle)")
                    .accessibilityHint("Double tap to show on map")
                }
                .listStyle(.plain)
                .frame(maxHeight: 260)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 4)
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}
