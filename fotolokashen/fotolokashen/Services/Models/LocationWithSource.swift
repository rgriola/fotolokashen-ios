import Foundation

/// Where a `LocationWithSource` entry came from when merging My Spots with friends/public locations.
enum LocationSource: Equatable {
    case own
    case friend
    case `public`
}

/// A `Location` tagged with its provenance for display in the merged "My Spots" list.
/// Kept separate from `Location` (a `Codable` API DTO reused pervasively) so this
/// UI-only concept doesn't leak into decoding/encoding elsewhere.
struct LocationWithSource: Identifiable, Equatable {
    let location: Location
    let source: LocationSource
    /// Present only for `.friend`/`.public` sources — carries owner info needed to
    /// build a read-only navigation context without re-deriving it from `Location`.
    let socialLocation: MapSocialLocation?

    var id: Int { location.id }

    static func == (lhs: LocationWithSource, rhs: LocationWithSource) -> Bool {
        lhs.id == rhs.id && lhs.source == rhs.source
    }
}
