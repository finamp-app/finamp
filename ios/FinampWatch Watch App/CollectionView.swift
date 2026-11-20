import SwiftUI

struct CollectionView: View {
    let collection: LibraryItem
    let type: String
    let onPlay: () -> Void
    @State private var state: ListState = .loading
    @State private var hasMore = false
    // Count received rows, including duplicates, for the next offset.
    @State private var phoneOffset = 0
    @State private var isLoadingMore = false
    private static let pageSize = 50
    @Environment(\.openLibraryDestination) private var open
    // Refresh on appear; parent download can change lock state.
    @State private var downloadState: (downloaded: Bool, lock: String?)?

    var body: some View {
        Group {
            switch state {
            case .loading:
                // The real header (its name, cover and totals are known) over placeholder tracks, in the same list
                List {
                    header([])
                        .clearListRow()
                    SkeletonTrackRows(count: 4, hearts: true, enlarged: true)
                }
                .cardList()
            case .failed(let message):
                RetryView(message: message) { await load() }
            case .loaded(let tracks):
                List {
                    header(tracks)
                        .clearListRow()
                    if tracks.isEmpty {
                        Text(type == "favorites" ? String(localized: "No favorite tracks yet") : String(localized: "No tracks"))
                            .font(.footnote)
                            .foregroundStyle(Color.fgSecondary)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(tracks) { track in
                        TrackRow(
                            track: track,
                            onFavorite: { Task { await FavoriteOverrides.shared.toggle(track) } },
                            favorite: FavoriteOverrides.shared.value(for: track),
                            onTap: { Task { await play(startId: track.id, index: tracks.firstIndex { $0.id == track.id }) } },
                            enlarged: true
                        )
                        .cardRow(isPlaying: NowPlayingStore.shared.nowPlaying.id == track.id)
                        .onAppear {
                            if tracks.suffix(pagePrefetchRows).contains(where: { $0.id == track.id }) {
                                Task { await loadMore() }
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
        .task { if case .loading = state { await load() } }
    }

    private var collectionFavorite: Bool { FavoriteOverrides.shared.value(for: collection) }

    // While the tracks load, a count the phone hasn't sent yet shows as a placeholder, not "0 Tracks".
    private var countUnknown: Bool {
        if case .loading = state { return collection.trackCount == 0 }
        return false
    }

    @ViewBuilder
    private func header(_ tracks: [LibraryItem]) -> some View {
        if type == "favorites" {
            VStack(alignment: .leading, spacing: PageHeader.favoritesLogoToHeading) {
                HalvesCoverRow {
                    FavoritesLogo(symbol: LibraryKind.tracks.placeholderSymbol)
                } info: {
                    StatLine(symbol: "music.note", text: trackSummary(tracks))
                        .redacted(reason: countUnknown ? .placeholder : [])
                }
                // Separates the logo from the tracks, as the queue's "Up Next" does.
                SectionHeader(title: LibraryKind.tracks.title)
            }
        } else {
            collectionHeader(tracks)
        }
    }

    private func collectionHeader(_ tracks: [LibraryItem]) -> some View {
        VStack(alignment: .leading, spacing: PageHeader.spacing) {
            PageTitleRow(
                title: collection.name,
                favorite: type == "favorites" ? nil : collectionFavorite,
                onFavorite: { Task { await FavoriteOverrides.shared.toggle(collection) } }
            ) {
                if type != "favorites" {
                    PhoneDownloadButton(
                        item: collection,
                        initiallyDownloaded: downloadState?.downloaded ?? collection.downloaded,
                        lock: downloadState.map { $0.lock } ?? collection.downloadLock,
                        itemType: type == "playlists" ? "playlist" : "album"
                    )
                }
            }
            HStack(alignment: .center, spacing: PageHeader.coverToStats) {
                Group {
                    if type == "favorites" {
                        FavoritesLogo(symbol: LibraryKind.tracks.placeholderSymbol)
                    } else {
                        CoverView(item: collection)
                    }
                }
                // The cover and the text share the row in halves.
                .frame(maxWidth: .infinity)
                // Finamp's stats, one line each (long ones scroll): album artists, tracks (total time), release
                // date; a playlist has only its tracks.
                VStack(alignment: .leading, spacing: PageHeader.statSpacing) {
                    if type != "playlists", !headerArtists.isEmpty {
                        // A NavigationLink here would make the entire header row tappable.
                        Marquee {
                            HStack(spacing: PageHeader.artistChipSpacing) {
                                ForEach(headerArtists) { artist in
                                    ArtistChip(artist: artist)
                                    .contentShape(Rectangle())
                                    .onTapGesture { open(.artistAlbums(artist)) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("Artist \(artist.name)")
                                }
                            }
                        }
                    } else if type != "playlists", !collection.subtitle.isEmpty {
                        Marquee {
                            Text(collection.subtitle)
                                .font(.footnote)
                                .foregroundStyle(Color.finampBlue)
                        }
                    }
                    StatLine(symbol: "music.note", text: trackSummary(tracks))
                        .redacted(reason: countUnknown ? .placeholder : [])
                    if type == "albums" {
                        StatLine(symbol: "calendar", text: releaseDate)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            // Equal columns; the heart is in the title row.
            HStack(spacing: 0) {
                LabeledIconButton(title: "Play", systemImage: "play") { await play(shuffle: false) }
                LabeledIconButton(title: "Shuffle", systemImage: "shuffle") { await play(shuffle: true) }
            }
            // The buttons reach out to the card edge, each in an equal share.
            .sameLabelSize()
            .widenToCardEdge()
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
            artworkKey: "artist-\(collection.artistID)",
            artworkURL: collection.artistArtworkURL
        )]
    }

    // As Finamp: "13 Tracks (51:20)".
    private func trackSummary(_ tracks: [LibraryItem]) -> String {
        let count = FinampFormat.tracks(max(collection.trackCount, tracks.count))
        let total = collection.duration > 0 ? collection.duration : tracks.reduce(0) { $0 + $1.duration }
        return "\(count) (\(FinampFormat.duration(total)))"
    }

    // In Finamp's chosen release date format, sent by the phone; the year from older phones.
    private var releaseDate: String {
        if !collection.releaseDate.isEmpty { return collection.releaseDate }
        return collection.year > 0 ? String(collection.year) : String(localized: "No Release Date")
    }

    private func load() async {
        state = .loading
        do {
            let first = try await PhoneConnection.shared.list(type, parentId: collection.id, limit: Self.pageSize)
            hasMore = !first.isEmpty
            phoneOffset = first.count
            state = .loaded(first)
        } catch {
            state = .failed(error.localizedDescription)
        }
        if type != "favorites" {
            downloadState = try? await PhoneConnection.shared.downloadState(collection.id)
        }
    }

    private func loadMore() async {
        guard hasMore, !isLoadingMore, case .loaded(let current) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await PhoneConnection.shared.list(
            type, parentId: collection.id, offset: phoneOffset, limit: Self.pageSize
        ) else { return }
        let known = Set(current.map(\.id))
        state = .loaded(current + page.filter { !known.contains($0.id) })
        phoneOffset += page.count
        hasMore = !page.isEmpty
    }

    // Favourites play a window around the tapped track (its index), so any favourite plays however long the list is.
    private func play(startId: String? = nil, index: Int? = nil, shuffle: Bool = false) async {
        do {
            let extra: [String: Any] = type == "favorites" ? index.map { ["index": $0] } ?? [:] : [:]
            try await PhoneConnection.shared.play(type, parentId: collection.id, startId: startId, shuffle: shuffle, extra: extra)
            onPlay()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
