import SwiftUI

struct CollectionView: View {
    let collection: LibraryItem
    let type: String
    let onPlay: () -> Void
    @State private var pager: Pager
    @Environment(\.openLibraryDestination) private var open
    // Refresh on appear; parent download can change lock state.
    @State private var downloadState: (downloaded: Bool, lock: String?)?
    // Favourite Tracks: the whole list's length, from the phone (the list itself loads in pages).
    @State private var favoritesTotal: Int?
    // The collection again from the phone, after the playlist menu changed it.
    @State private var latest: LibraryItem?

    init(collection: LibraryItem, type: String, onPlay: @escaping () -> Void) {
        self.collection = collection
        self.type = type
        self.onPlay = onPlay
        _pager = State(initialValue: Pager { offset, limit in
            try await PhoneConnection.shared.list(type, parentId: collection.id, offset: offset, limit: limit)
        })
    }

    var body: some View {
        Group {
            switch pager.state {
            case .loading:
                // The real header (its name, cover and totals are known) over placeholder tracks, in the same list
                List {
                    header([])
                        .clearListRow()
                    tracksSection { SkeletonTrackRows(count: 4, hearts: true, enlarged: true) }
                }
                .cardList()
            case .failed(let message):
                RetryView(message: message) { await load() }
            case .loaded(let tracks):
                List {
                    header(tracks)
                        .clearListRow()
                    tracksSection {
                        if tracks.isEmpty {
                            EmptyNote(
                                text: type == "favorites" ? String(localized: "No favorite tracks yet") : String(localized: "No tracks"),
                                inList: true
                            )
                            .clearListRow()
                        }
                        ForEach(tracks) { track in
                            TrackRow(
                                track: track,
                                heart: true,
                                onTap: { Task { await play(startId: track.id, index: tracks.firstIndex { $0.id == track.id }) } },
                                enlarged: true
                            )
                            .cardRow(isPlaying: NowPlayingStore.shared.nowPlaying.id == track.id)
                            .onAppear {
                                if pager.nearsEnd(track.id, in: tracks) { Task { await pager.loadMore() } }
                            }
                        }
                    }
                }
                .cardList()
            }
        }
        // Favorite Tracks has its name at the top right, as the queue's "Now Playing"; other pages use the title row.
        .navigationTitle(type == "favorites" ? collection.name : "")
        .accentTitle()
        .task { if case .loading = pager.state { await load() } }
        // A playlist the playlist menu changed: its tracks, count and duration again.
        .onChange(of: PlaylistEdits.shared.edits[collection.id]) {
            Task {
                if let item = try? await PhoneConnection.shared.item(collection.id) { latest = item }
                await pager.reload()
            }
        }
    }

    // The collection as the phone last sent it.
    private var stats: LibraryItem { latest ?? collection }

    private var collectionFavorite: Bool { FavoriteOverrides.shared.value(for: collection) }

    // A count the phone hasn't sent yet shows as a placeholder, not "0 Tracks" or the first page's length.
    private var countUnknown: Bool {
        if type == "favorites", favoritesTotal == nil {
            if case .loaded = pager.state { return pager.hasMore }
            return true
        }
        if case .loading = pager.state { return stats.trackCount == 0 }
        return false
    }

    @ViewBuilder
    private func header(_ tracks: [LibraryItem]) -> some View {
        if type == "favorites" {
            PageCoverRow {
                FavoritesLogo()
            } info: {
                StatLine(symbol: "music.note", text: trackSummary(tracks))
                    .redacted(reason: countUnknown ? .placeholder : [])
            }
        } else {
            collectionHeader(tracks)
        }
    }

    // Favorite Tracks' tracks under a heading that separates them from the logo, as the queue's "Up Next" does.
    @ViewBuilder
    private func tracksSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if type == "favorites" {
            HeadedSection(title: LibraryKind.tracks.title, content: content)
        } else {
            content()
        }
    }

    private func collectionHeader(_ tracks: [LibraryItem]) -> some View {
        VStack(alignment: .leading, spacing: PageHeader.spacing) {
            PageTitleRow(
                title: collection.name,
                favorite: collectionFavorite,
                onFavorite: { Task { await FavoriteOverrides.shared.toggle(collection) } }
            ) {
                PhoneDownloadButton(
                    item: collection,
                    initiallyDownloaded: downloadState?.downloaded ?? collection.downloaded,
                    lock: downloadState.map { $0.lock } ?? collection.downloadLock,
                    itemType: type == "playlists" ? "playlist" : "album"
                )
            }
            PageCoverRow {
                CoverView(item: collection)
            } info: {
                // Finamp's stats, one line each (long ones scroll): album artists, tracks (total time), release
                // date; a playlist has only its tracks.
                VStack(alignment: .leading, spacing: PageHeader.statSpacing) {
                    if type != "playlists" {
                        ArtistChipsLine(artists: headerArtists, fallback: collection.subtitle) { open(.artistAlbums($0)) }
                    }
                    StatLine(symbol: "music.note", text: trackSummary(tracks))
                        .redacted(reason: countUnknown ? .placeholder : [])
                    if type == "albums" {
                        StatLine(symbol: "calendar", text: releaseDate)
                    }
                }
            }
            // The heart is in the title row.
            ButtonStrip {
                LabeledIconButton(title: "Play", systemImage: "play") { await play(shuffle: false) }
                LabeledIconButton(title: "Shuffle", systemImage: "shuffle") { await play(shuffle: true) }
            }
        }
    }

    // Fall back to collection artist if full artist list is absent.
    private var headerArtists: [LibraryItem] {
        if !collection.artists.isEmpty { return collection.artists }
        guard !collection.artistID.isEmpty else { return [] }
        return [LibraryItem(
            id: collection.artistID,
            name: collection.subtitle,
            subtitle: "",
            artworkKey: "artist-\(collection.artistID)"
        )]
    }

    // As Finamp: "13 Tracks (51:20)".
    private func trackSummary(_ tracks: [LibraryItem]) -> String {
        let known = max(favoritesTotal ?? stats.trackCount, tracks.count)
        let count = FinampFormat.tracks(known)
        // The duration only when it covers every track (Favourite Tracks loads in pages and has no total duration).
        if stats.duration > 0 { return "\(count) (\(FinampFormat.duration(stats.duration)))" }
        guard tracks.count >= known else { return count }
        return "\(count) (\(FinampFormat.duration(tracks.reduce(0) { $0 + $1.duration })))"
    }

    // The phone's release date in Finamp's format; the year when there is none.
    private var releaseDate: String {
        if !collection.releaseDate.isEmpty { return collection.releaseDate }
        return collection.year > 0 ? String(collection.year) : String(localized: "No Release Date")
    }

    private func load() async {
        await pager.load()
        if type == "favorites" {
            favoritesTotal = try? await PhoneConnection.shared.favoritesCount()
        } else {
            downloadState = try? await PhoneConnection.shared.downloadState(collection.id)
        }
    }

    // Favourites play a window around the tapped track (its index), so any favourite plays however long the list is.
    private func play(startId: String? = nil, index: Int? = nil, shuffle: Bool = false) async {
        do {
            let extra: [String: Any] = type == "favorites" ? index.map { ["index": $0] } ?? [:] : [:]
            try await PhoneConnection.shared.play(type, parentId: collection.id, startId: startId, shuffle: shuffle, extra: extra)
            onPlay()
        } catch {
            PhoneMessage.show(error)
        }
    }
}
