import SwiftUI

struct ArtistView: View {
    let artist: LibraryItem
    let onPlay: () -> Void

    // Finamp's artist screen sections: their albums, and the albums they appear on.
    @State private var pager: Pager
    @State private var appearsOn: Pager
    @State private var info: ArtistInfo?

    init(artist: LibraryItem, onPlay: @escaping () -> Void) {
        self.artist = artist
        self.onPlay = onPlay
        _pager = State(initialValue: Pager { offset, limit in
            try await PhoneConnection.shared.list("artists", parentId: artist.id, offset: offset, limit: limit)
        })
        _appearsOn = State(initialValue: Pager { offset, limit in
            try await PhoneConnection.shared.list("appearsOn", parentId: artist.id, offset: offset, limit: limit)
        })
    }

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
                switch pager.state {
                case .loading:
                    SkeletonCoverRows(count: 3, coverShare: LibraryKind.albums.coverShare, sectionHeader: true)
                case .failed(let message):
                    RetryView(message: message) { await load() }
                case .loaded(let albums):
                    if albums.isEmpty, case .loaded(let other) = appearsOn.state, other.isEmpty {
                        Text("No albums")
                            .font(.footnote)
                            .foregroundStyle(Color.fgSecondary)
                    } else {
                        // In the order of Finamp's artist screen setting; a section with nothing in it isn't shown.
                        ForEach(info?.sections ?? ["albums", "appearsOn"], id: \.self) { section in
                            if section == "appearsOn" {
                                albumSection(String(localized: "Appears On"), appearsOn)
                            } else {
                                albumSection(String(localized: "Albums"), pager)
                            }
                        }
                    }
                }
            }
            .clearListRow()
        }
        .navigationTitle("")
        .coverList()
        .task { if case .loading = pager.state { await load() } }
    }

    // A section of albums under its heading.
    @ViewBuilder
    private func albumSection(_ title: String, _ section: Pager) -> some View {
        if case .loaded(let albums) = section.state, !albums.isEmpty {
            HeadedSection(title: title) {
                ForEach(albums) { album in
                    CollectionLink(item: album, kind: .albums)
                        .coverListRow()
                        .onAppear {
                            if section.nearsEnd(album.id, in: albums) { Task { await section.loadMore() } }
                        }
                }
            }
        }
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
            PageCoverRow {
                // A rounded square here, round in lists.
                CoverView(item: artist)
            } info: {
                VStack(alignment: .leading, spacing: PageHeader.statSpacing) {
                    // Finamp's artist stats: tracks, then albums.
                    if let info { StatLine(symbol: "music.note", text: FinampFormat.tracks(info.tracks)) }
                    if let albums = albumCount { StatLine(symbol: "opticaldisc", text: FinampFormat.albums(albums)) }
                }
            }
            ButtonStrip {
                LabeledIconButton(title: "Play", systemImage: "play") { await play() }
                LabeledIconButton(title: "Shuffle", systemImage: "shuffle") { await play(shuffle: true) }
                LabeledIconButton(title: "Shuffle\nAlbums", systemImage: "shuffle", titleLines: 2) {
                    await play(albumShuffle: true)
                }
            }
        }
    }

    // Use the phone total, or the loaded count after the last page.
    private var albumCount: Int? {
        if let info { return info.albums }
        if case .loaded(let albums) = pager.state, !pager.hasMore { return albums.count }
        return nil
    }

    private func load() async {
        async let albums: Void = pager.load()
        async let others: Void = appearsOn.load()
        _ = await (albums, others)
        info = try? await PhoneConnection.shared.artistInfo(artist.id)
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
            pager.fail(error.localizedDescription)
        }
    }
}
