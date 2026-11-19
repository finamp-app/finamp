import SwiftUI

enum LibraryKind: String {
    case artists, albums, playlists, tracks, downloads

    var type: String { rawValue }

    var title: String {
        switch self {
        case .artists: return String(localized: "Artists")
        case .albums: return String(localized: "Albums")
        case .playlists: return String(localized: "Playlists")
        case .tracks: return String(localized: "Tracks")
        case .downloads: return String(localized: "Downloads")
        }
    }

    var coverShare: CGFloat {
        switch self {
        case .tracks: return CoverRows.trackCoverShare
        case .albums, .playlists, .downloads: return CoverRows.albumCoverShare
        case .artists: return CoverRows.artistCoverShare
        }
    }

    var placeholderSymbol: String {
        switch self {
        case .artists: return "music.mic"
        case .albums: return "square.stack.fill"
        case .playlists: return "music.note.list"
        case .tracks: return "music.note"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
}

// Prefetch next page before reaching the end.
let pagePrefetchRows = 10

enum ListState {
    case loading
    case loaded([LibraryItem])
    case failed(String)
}

struct LibraryPage: View {
    let kind: LibraryKind
    // Page views are created at launch; only fetch while visible.
    let isActive: Bool
    let onPlay: () -> Void

    static let pageSize = 50

    @State private var items: [LibraryItem]?
    @State private var error: String?
    @State private var hasMore = true
    @State private var isLoadingMore = false
    @State private var isReloading = false
    // Invalidate in-flight pages on reload.
    @State private var generation = 0
    @State private var path: [LibraryDestination] = []

    var body: some View {
        LibraryNavigationStack(path: $path) {
            Group {
                if let items, items.isEmpty {
                    Text(kind == .downloads ? String(localized: "Nothing downloaded on your iPhone") : String(localized: "Nothing here"))
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .multilineTextAlignment(.center)
                } else if let items, kind == .tracks {
                    // List supplies watchOS's shrinking rows at the screen edges.
                    List {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            trackRow(item, index: index)
                                .cardRow(isPlaying: NowPlayingStore.shared.nowPlaying.id == item.id)
                                .onAppear {
                                    if index >= items.count - pagePrefetchRows { Task { await loadMore() } }
                                }
                        }
                        if isLoadingMore {
                            SkeletonTrackRows(count: 1, hearts: true, enlarged: true)
                        }
                    }
                    .cardList()
                } else if let items {
                    // A List like the track pages, for watchOS's shrinking rows at the screen edges.
                    List {
                        Group {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                row(item, index: index)
                                    .onAppear {
                                        if index >= items.count - pagePrefetchRows { Task { await loadMore() } }
                                    }
                            }
                            if isLoadingMore {
                                SkeletonCoverRows(count: 1, coverShare: kind.coverShare, circular: kind == .artists)
                            }
                        }
                        .coverListRow()
                    }
                    .coverList()
                } else if let error {
                    RetryView(message: error) { await reload() }
                } else if kind == .tracks {
                    // Placeholders in the same list, with the same rows, as the loaded page (Skeleton.swift)
                    List {
                        SkeletonTrackRows(hearts: true, enlarged: true)
                    }
                    .cardList()
                } else {
                    List {
                        Group {
                            SkeletonCoverRows(
                                coverShare: kind.coverShare, circular: kind == .artists, sectionHeader: kind == .downloads
                            )
                        }
                        .coverListRow()
                    }
                    .coverList()
                }
            }
            .navigationTitle(kind.title)
            .libraryDestinations(onPlay: onPlay)
            .themedBackground()
        }
        // Refresh on each visit so server changes appear without relaunching.
        .onChange(of: isActive, initial: true) { _, active in
            if active { Task { await reload() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .phoneBecameReachable)) { _ in
            if isActive && items == nil { Task { await reload(quiet: true) } }
        }
        // Start over when Offline Mode changes, as Finamp's library tabs do: the other mode lists other items.
        .onChange(of: PhoneSettings.shared.offline) {
            items = nil
            error = nil
            hasMore = true
            generation += 1
            if isActive { Task { await reload(quiet: true) } }
        }
    }

    @ViewBuilder
    private func row(_ item: LibraryItem, index: Int) -> some View {
        switch kind {
        case .albums, .playlists, .artists:
            CollectionLink(item: item, kind: kind)
        case .downloads:
            let itemKind = Self.downloadKind(item.kind)
            VStack(alignment: .leading, spacing: CoverRows.headingToRow) {
                if index == 0 || items?[index - 1].kind != item.kind {
                    SectionHeader(title: itemKind.title)
                }
                CollectionLink(item: item, kind: itemKind)
            }
        case .tracks:
            trackRow(item, index: index)
        }
    }

    private static func downloadKind(_ kind: String) -> LibraryKind {
        switch kind {
        case "artists": return .artists
        case "playlists": return .playlists
        default: return .albums
        }
    }

    private func trackRow(_ item: LibraryItem, index: Int) -> some View {
        TrackRow(
            track: item,
            onFavorite: { Task { await FavoriteOverrides.shared.toggle(item) } },
            favorite: FavoriteOverrides.shared.value(for: item),
            onTap: { Task { await playTrack(item, index: index) } },
            enlarged: true
        )
    }

    // Keep later pages only if the first page has not shifted; errors replace empty content.
    // `quiet`: the phone caused it (back in reach, Offline Mode changed there), not a tap.
    private func reload(quiet: Bool = false) async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        do {
            // Fetch again if Offline Mode changed while this page was on its way.
            var firstPage: [LibraryItem]
            var started: Int
            var again = false
            repeat {
                started = generation
                // A fetch again because Offline Mode changed meanwhile is the phone's doing.
                firstPage = try await PhoneConnection.shared.list(
                    kind.type, offset: 0, limit: Self.pageSize, quiet: quiet || again
                )
                again = true
            } while generation != started
            if let current = items, !firstPage.isEmpty, current.count > firstPage.count,
               current.prefix(firstPage.count).map(\.id) == firstPage.map(\.id) {
                items = firstPage + current.dropFirst(firstPage.count)
            } else {
                items = firstPage
                hasMore = !firstPage.isEmpty
                generation += 1
            }
            error = nil
        } catch {
            if items == nil { self.error = error.localizedDescription }
        }
    }

    private func loadMore() async {
        guard let current = items, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let started = generation
        do {
            let page = try await PhoneConnection.shared.list(kind.type, offset: current.count, limit: Self.pageSize)
            guard generation == started, let latest = items else { return }
            let known = Set(latest.map(\.id))
            items = latest + page.filter { !known.contains($0.id) }
            hasMore = !page.isEmpty
        } catch {
            // Scrolling to the end again retries
        }
    }

    private func playTrack(_ track: LibraryItem, index: Int) async {
        do {
            try await PhoneConnection.shared.playTracks(index: index, startId: track.id)
            onPlay()
        } catch {
            PhoneMessage.shared.text = error.localizedDescription
        }
    }
}
