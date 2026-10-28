import SwiftUI

/// A collection's tracks and playback actions.
struct CollectionView: View {
    let collection: LibraryItem
    let type: String
    let onPlay: () -> Void
    @State private var state: ListState = .loading
    /// Albums and playlists load a page at a time as the list scrolls; favourites come at once.
    @State private var hasMore = false
    @State private var isLoadingMore = false
    private static let pageSize = 100
    @Environment(\.openLibraryDestination) private var open
    /// Refresh on opening: a parent download can change the lock after the list loads.
    @State private var downloadState: (downloaded: Bool, lock: String?)?

    var body: some View {
        Group {
            switch state {
            case .loading:
                SkeletonTrackList()
            case .failed(let message):
                RetryView(message: message) { await load() }
            case .loaded(let tracks):
                List {
                    header(tracks)
                        .listRowBackground(Color.clear)
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
                            onTap: { Task { await play(startId: track.id) } },
                            enlarged: true
                        )
                        .listRowBackground(TrackRowBackground(isPlaying: NowPlayingStore.shared.nowPlaying.id == track.id))
                        .onAppear {
                            if track.id == tracks.last?.id { Task { await loadMore() } }
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        // watchOS allows one corner button; keep the heart beside Play and Shuffle.
        .phoneDownloadButton(
            for: collection,
            downloaded: downloadState?.downloaded ?? collection.downloaded,
            lock: downloadState.map { $0.lock } ?? collection.downloadLock,
            shown: type != "favorites"
        )
        .task { if case .loading = state { await load() } }
    }

    private var collectionFavorite: Bool { FavoriteOverrides.shared.value(for: collection) }

    private func header(_ tracks: [LibraryItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if type == "favorites" {
                        FavoritesLogo(symbol: LibraryKind.tracks.placeholderSymbol)
                    } else {
                        CoverView(item: collection, placeholderSymbol: coverSymbol)
                    }
                }
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.42 }
                VStack(alignment: .leading, spacing: 3) {
                    Text(collection.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.fgPrimary)
                        .lineLimit(3)
                    if !headerArtists.isEmpty {
                        // A NavigationLink here would make the entire header row tappable.
                        Marquee {
                            HStack(spacing: 8) {
                                ForEach(headerArtists) { artist in
                                    ArtistLabel(artist: artist, color: .finampBlue)
                                    .contentShape(Rectangle())
                                    .onTapGesture { open(.artistAlbums(artist)) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("Artist \(artist.name)")
                                }
                            }
                        }
                    } else if !collection.subtitle.isEmpty {
                        Text(collection.subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.finampBlue)
                            .lineLimit(1)
                    }
                    Text(trackSummary(tracks))
                        .font(.caption2)
                        .foregroundStyle(Color.fgSecondary)
                    if collection.year > 0 {
                        Text(String(collection.year))
                            .font(.caption2)
                            .foregroundStyle(Color.fgSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                LabeledIconButton(title: "Play", systemImage: "play") { await play(shuffle: false) }
                LabeledIconButton(title: "Shuffle", systemImage: "shuffle") { await play(shuffle: true) }
                if type != "favorites" {
                    LabeledIconButton(
                        title: "Like",
                        systemImage: collectionFavorite ? "heart.fill" : "heart",
                        tint: collectionFavorite ? .finampPurple : .finampBlue
                    ) { await FavoriteOverrides.shared.toggle(collection) }
                }
            }
        }
    }

    /// Falls back to the row's artist when the phone has not supplied the full artist list.
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

    private func trackSummary(_ tracks: [LibraryItem]) -> String {
        // The collection's own count and length when known, since a long list is only partly loaded
        let trackCount = max(collection.trackCount, tracks.count)
        let count = trackCount == 1 ? String(localized: "1 track") : String(localized: "\(trackCount) tracks")
        let total = collection.duration > 0 ? collection.duration : tracks.reduce(0) { $0 + $1.duration }
        return total > 0 ? "\(count) · \(formatDuration(total))" : count
    }

    private var coverSymbol: String {
        switch type {
        case "favorites": return "heart.fill"
        case "playlists": return LibraryKind.playlists.placeholderSymbol
        default: return LibraryKind.albums.placeholderSymbol
        }
    }

    private func load() async {
        state = .loading
        do {
            let paged = type != "favorites"
            let first = try await PhoneConnection.shared.list(type, parentId: collection.id, limit: Self.pageSize)
            hasMore = paged && first.count == Self.pageSize
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
            type, parentId: collection.id, offset: current.count, limit: Self.pageSize
        ) else { return }
        let known = Set(current.map(\.id))
        state = .loaded(current + page.filter { !known.contains($0.id) })
        hasMore = page.count == Self.pageSize
    }

    private func play(startId: String? = nil, shuffle: Bool = false) async {
        do {
            try await PhoneConnection.shared.play(type, parentId: collection.id, startId: startId, shuffle: shuffle)
            onPlay()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
