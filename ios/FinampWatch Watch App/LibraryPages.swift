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
}

// Prefetch next page before reaching the end.
let pagePrefetchRows = 10

enum ListState {
    case loading
    case loaded([LibraryItem])
    case failed(String)
}

// The paging the album/playlist, artist and favourites pages share: the first page, then the next as the list nears
// its end (`nearsEnd`). The offset counts every row the phone sent, and a row it sends twice is kept once (a playlist
// can hold a track twice).
@MainActor @Observable
final class Pager {
    static let pageSize = 50
    private(set) var state: ListState = .loading
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    @ObservationIgnored private var phoneOffset = 0
    @ObservationIgnored private let fetch: (_ offset: Int, _ limit: Int) async throws -> [LibraryItem]

    init(fetch: @escaping (_ offset: Int, _ limit: Int) async throws -> [LibraryItem]) {
        self.fetch = fetch
    }

    func load() async {
        state = .loading
        do {
            let first = try await fetch(0, Self.pageSize)
            hasMore = !first.isEmpty
            phoneOffset = first.count
            state = .loaded(first)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // The list again from its start, the shown one kept until it arrives (a playlist the playlist menu changed).
    func reload() async {
        guard let first = try? await fetch(0, Self.pageSize) else { return }
        hasMore = !first.isEmpty
        phoneOffset = first.count
        state = .loaded(first)
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, case .loaded(let current) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await fetch(phoneOffset, Self.pageSize) else { return }
        let known = Set(current.map(\.id))
        state = .loaded(current + page.filter { !known.contains($0.id) })
        phoneOffset += page.count
        hasMore = !page.isEmpty
    }

    // A failure shown in place of the list (a play that failed).
    func fail(_ message: String) {
        state = .failed(message)
    }

    // The last rows ask for the next page.
    func nearsEnd(_ id: String, in items: [LibraryItem]) -> Bool {
        items.suffix(pagePrefetchRows).contains { $0.id == id }
    }
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
                            if kind == .downloads {
                                // Each kind under its heading, in the phone's order.
                                ForEach(Self.kindRuns(items), id: \.first) { run in
                                    HeadedSection(title: Self.downloadKind(items[run.first!].kind).title) {
                                        coverRows(items, run)
                                    }
                                }
                            } else {
                                coverRows(items, items.indices)
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

    private func coverRows(_ items: [LibraryItem], _ indices: Range<Int>) -> some View {
        ForEach(Array(zip(indices, items[indices])), id: \.1.id) { index, item in
            CollectionLink(item: item, kind: kind == .downloads ? Self.downloadKind(item.kind) : kind)
                .onAppear {
                    if index >= items.count - pagePrefetchRows { Task { await loadMore() } }
                }
        }
    }

    // The ranges of `items` that hold one kind each.
    private static func kindRuns(_ items: [LibraryItem]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start = 0
        for index in items.indices.dropFirst() where items[index].kind != items[index - 1].kind {
            runs.append(start..<index)
            start = index
        }
        if !items.isEmpty { runs.append(start..<items.count) }
        return runs
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
            PhoneMessage.show(error)
        }
    }
}
