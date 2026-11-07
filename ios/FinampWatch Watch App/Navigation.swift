import SwiftUI

/// A destination within a library page.
enum LibraryDestination: Hashable {
    /// A collection's tracks; `type` is "albums", "playlists" or "favorites".
    case tracks(LibraryItem, type: String)
    case artistAlbums(LibraryItem)
    case favoriteAlbums
    case favoriteArtists
    case search(String)

    static let favorites = LibraryDestination.tracks(
        LibraryItem(id: "favorites", name: String(localized: "Favorite Tracks"), subtitle: "", artworkKey: ""),
        type: "favorites"
    )
}

extension LibraryDestination {
    /// Identifies a screen independent of the extra fields carried by different entry points.
    var screenKey: String {
        switch self {
        case .tracks(let item, let type): return "\(type):\(item.id)"
        case .artistAlbums(let artist): return "artist:\(artist.id)"
        case .favoriteAlbums: return "favoriteAlbums"
        case .favoriteArtists: return "favoriteArtists"
        case .search(let query): return "search:\(query)"
        }
    }
}

/// Moves an existing screen to the top so Back returns to the caller; drops oldest past maxDepth.
enum LibraryPath {
    static let maxDepth = 10

    static func opening(_ destination: LibraryDestination, in path: [LibraryDestination]) -> [LibraryDestination] {
        var path = path.filter { $0.screenKey != destination.screenKey }
        path.append(destination)
        if path.count > maxDepth { path.removeFirst(path.count - maxDepth) }
        return path
    }

    /// Routes SwiftUI pushes through `opening` while preserving pops.
    static func applying(_ new: [LibraryDestination], to old: [LibraryDestination]) -> [LibraryDestination] {
        guard new.count == old.count + 1, let pushed = new.last, Array(new.dropLast()) == old else { return new }
        return opening(pushed, in: old)
    }
}

extension EnvironmentValues {
    /// Opens without a NavigationLink, which would make an entire list row tappable.
    @Entry var openLibraryDestination: (LibraryDestination) -> Void = { _ in }
}

/// Uses one destination path per page to avoid mixing SwiftUI presentation mechanisms.
struct LibraryNavigationStack<Root: View>: View {
    @Binding var path: [LibraryDestination]
    @ViewBuilder let root: Root

    var body: some View {
        NavigationStack(path: Binding(get: { path }, set: { path = LibraryPath.applying($0, to: path) })) {
            root
        }
        .environment(\.openLibraryDestination) { destination in
            path = LibraryPath.opening(destination, in: path)
        }
    }
}

extension View {
    /// Registers the destinations shared by library pages.
    func libraryDestinations(onPlay: @escaping () -> Void) -> some View {
        navigationDestination(for: LibraryDestination.self) { destination in
            Group {
                switch destination {
                case .tracks(let collection, let type):
                    CollectionView(collection: collection, type: type, onPlay: onPlay)
                case .artistAlbums(let artist):
                    ArtistView(artist: artist, onPlay: onPlay)
                case .favoriteAlbums:
                    FavoritesListView(title: String(localized: "Favorite Albums"), type: "favoriteAlbums", onPlay: onPlay)
                case .favoriteArtists:
                    FavoritesListView(title: String(localized: "Favorite Artists"), type: "favoriteArtists", onPlay: onPlay)
                case .search(let query):
                    SearchResultsView(query: query, onPlay: onPlay)
                }
            }
            .themedBackground()
        }
    }
}
