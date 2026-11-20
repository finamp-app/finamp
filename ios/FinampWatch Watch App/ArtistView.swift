import SwiftUI

struct ArtistView: View {
    let artist: LibraryItem
    let onPlay: () -> Void

    @State private var state: ListState = .loading
    @State private var hasMore = false
    // Count received rows, including duplicates, for the next offset.
    @State private var phoneOffset = 0
    @State private var isLoadingMore = false
    private static let pageSize = 50
    @State private var info: ArtistInfo?

    // Playback artist chips do not carry favourite state.
    private var item: LibraryItem {
        var item = artist
        if let info { item.favorite = info.favorite }
        return item
    }

    var body: some View {
        // A List like the track pages, for watchOS's shrinking rows at the screen edges.
        List {
            Group {
                header
                switch state {
                case .loading:
                    SkeletonCoverRows(count: 3, coverShare: LibraryKind.albums.coverShare)
                case .failed(let message):
                    RetryView(message: message) { await load() }
                case .loaded(let albums) where albums.isEmpty:
                    Text("No albums")
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                case .loaded(let albums):
                    ForEach(albums) { album in
                        CollectionLink(item: album, kind: .albums)
                            .coverListRow()
                            .onAppear {
                                if albums.suffix(pagePrefetchRows).contains(where: { $0.id == album.id }) {
                                    Task { await loadMore() }
                                }
                            }
                    }
                }
            }
            .clearListRow()
        }
        .navigationTitle("")
        .coverList()
        .task { if case .loading = state { await load() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PageHeader.spacing) {
            PageTitleRow(
                title: artist.name,
                favorite: FavoriteOverrides.shared.value(for: item),
                onFavorite: { Task { await FavoriteOverrides.shared.toggle(item) } }
            ) {
                PhoneDownloadButton(
                    item: artist, initiallyDownloaded: info?.downloaded ?? false, lock: info?.downloadLock, itemType: "artist"
                )
            }
            HStack(alignment: .center, spacing: PageHeader.coverToStats) {
                // A rounded square here, round in lists. The image and the text share the row in halves.
                CoverView(item: artist)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: PageHeader.statSpacing) {
                    // Finamp's artist stats: tracks, then albums.
                    if let info { StatLine(symbol: "music.note", text: FinampFormat.tracks(info.tracks)) }
                    if let albums = albumCount { StatLine(symbol: "opticaldisc", text: FinampFormat.albums(albums)) }
                }
                .frame(maxWidth: .infinity)
            }
            // Three equal columns, aligned at the top so the two-line label doesn't push the others down.
            HStack(alignment: .top, spacing: 0) {
                LabeledIconButton(title: "Play", systemImage: "play") { await play() }
                LabeledIconButton(title: "Shuffle", systemImage: "shuffle") { await play(shuffle: true) }
                LabeledIconButton(title: "Shuffle\nAlbums", systemImage: "shuffle", titleLines: 2) {
                    await play(albumShuffle: true)
                }
            }
            // The buttons reach out to the card edge, each in an equal share.
            .sameLabelSize()
            .widenToCardEdge()
            SectionHeader(title: String(localized: "Albums"))
        }
    }

    // Use the phone total, or the loaded count after the last page.
    private var albumCount: Int? {
        if let info { return info.albums }
        if case .loaded(let albums) = state, !hasMore { return albums.count }
        return nil
    }

    private func load() async {
        state = .loading
        do {
            let first = try await PhoneConnection.shared.list("artists", parentId: artist.id, limit: Self.pageSize)
            hasMore = !first.isEmpty
            phoneOffset = first.count
            state = .loaded(first)
        } catch {
            state = .failed(error.localizedDescription)
        }
        info = try? await PhoneConnection.shared.artistInfo(artist.id)
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore, case .loaded(let current) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await PhoneConnection.shared.list(
            "artists", parentId: artist.id, offset: phoneOffset, limit: Self.pageSize
        ) else { return }
        let known = Set(current.map(\.id))
        state = .loaded(current + page.filter { !known.contains($0.id) })
        phoneOffset += page.count
        hasMore = !page.isEmpty
    }

    private func play(shuffle: Bool = false, albumShuffle: Bool = false) async {
        do {
            try await PhoneConnection.shared.play(
                "artist",
                parentId: artist.id,
                shuffle: shuffle,
                extra: ["albumShuffle": albumShuffle]
            )
            onPlay()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
