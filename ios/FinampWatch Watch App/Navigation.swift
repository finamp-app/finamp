import SwiftUI

enum LibraryDestination: Hashable {
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
    // Ignore metadata differences between entry points to the same screen.
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

// Move an existing screen to the top so Back returns to the caller; drop the oldest past maxDepth.
enum LibraryPath {
    static let maxDepth = 10

    static func opening(_ destination: LibraryDestination, in path: [LibraryDestination]) -> [LibraryDestination] {
        var path = path.filter { $0.screenKey != destination.screenKey }
        path.append(destination)
        if path.count > maxDepth { path.removeFirst(path.count - maxDepth) }
        return path
    }

    // Deduplicate pushes while preserving pops.
    static func applying(_ new: [LibraryDestination], to old: [LibraryDestination]) -> [LibraryDestination] {
        guard new.count == old.count + 1, let pushed = new.last, Array(new.dropLast()) == old else { return new }
        return opening(pushed, in: old)
    }
}

extension EnvironmentValues {
    // Open without NavigationLink so row parts remain independently tappable.
    @Entry var openLibraryDestination: (LibraryDestination) -> Void = { _ in }
}

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
