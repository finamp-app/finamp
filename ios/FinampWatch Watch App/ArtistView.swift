import SwiftUI

/// An artist's albums and playback actions.
struct ArtistView: View {
    let artist: LibraryItem
    let onPlay: () -> Void

    @State private var state: ListState = .loading
    @State private var info: ArtistInfo?
    /// Measured column widths used to centre the icons.
    @State private var leftColumnWidth: CGFloat = 0
    @State private var rightColumnWidth: CGFloat = 0

    /// Uses the fetched favourite state because playback artist chips do not carry it.
    private var item: LibraryItem {
        var item = artist
        if let info { item.favorite = info.favorite }
        return item
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                header
                switch state {
                case .loading:
                    SkeletonCoverRows(count: 3, coverFraction: LibraryKind.albums.coverFraction)
                case .failed(let message):
                    RetryView(message: message) { await load() }
                case .loaded(let albums) where albums.isEmpty:
                    Text("No albums")
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                case .loaded(let albums):
                    ForEach(albums) { album in
                        CollectionLink(item: album, kind: .albums)
                    }
                }
            }
        }
        .navigationTitle("")
        .phoneDownloadButton(for: artist, downloaded: info?.downloaded ?? false, lock: info?.downloadLock)
        .task { if case .loading = state { await load() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                CoverView(item: artist, placeholderSymbol: LibraryKind.artists.placeholderSymbol, circular: true)
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.38 }
                VStack(alignment: .leading, spacing: 3) {
                    Text(artist.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.fgPrimary)
                        .lineLimit(3)
                    if let info {
                        count(
                            info.tracks == 1 ? String(localized: "1 track") : String(localized: "\(info.tracks) tracks"),
                            symbol: "music.note"
                        )
                    }
                    if case .loaded(let albums) = state {
                        count(
                            albums.count == 1 ? String(localized: "1 album") : String(localized: "\(albums.count) albums"),
                            symbol: "opticaldisc"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Align icons so a two-line label does not push its neighbour down.
            Grid(horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow(alignment: .top) {
                    LabeledIconButton(title: "Play", systemImage: "play", fills: false) { await play() }
                    LabeledIconButton(title: "Shuffle", systemImage: "shuffle", fills: false) { await play(shuffle: true) }
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rightColumnWidth = $0 }
                }
                GridRow(alignment: .top) {
                    LabeledIconButton(title: "Shuffle\nAlbums", systemImage: "shuffle", titleLines: 2, fills: false) {
                        await play(albumShuffle: true)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leftColumnWidth = $0 }
                    LabeledIconButton(
                        title: "Like",
                        systemImage: FavoriteOverrides.shared.value(for: item) ? "heart.fill" : "heart",
                        tint: FavoriteOverrides.shared.value(for: item) ? .finampPurple : .finampBlue,
                        fills: false
                    ) { await FavoriteOverrides.shared.toggle(item) }
                }
            }
            // Centre the midpoint between icons despite unequal column widths.
            .offset(x: (rightColumnWidth - leftColumnWidth) / 4)
            .frame(maxWidth: .infinity)
            SectionHeader(title: String(localized: "Albums"))
        }
    }

    private func count(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2)
            .foregroundStyle(Color.fgSecondary)
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await PhoneConnection.shared.list("artists", parentId: artist.id))
        } catch {
            state = .failed(error.localizedDescription)
        }
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
            state = .failed(error.localizedDescription)
        }
    }
}
