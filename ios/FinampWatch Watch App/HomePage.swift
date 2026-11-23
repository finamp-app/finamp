import SwiftUI

struct HomePage: View {
    let isActive: Bool
    let onPlay: () -> Void

    @State private var sections: HomeSections?
    @State private var error: String?
    @State private var isReloading = false
    @State private var path: [LibraryDestination] = []
    @State private var showSettings = false

    private static let favoriteCards: [(destination: LibraryDestination, title: String, kind: LibraryKind)] = [
        (.favoriteAlbums, String(localized: "Favorite Albums"), .albums),
        (.favoriteArtists, String(localized: "Favorite Artists"), .artists),
        (.favorites, String(localized: "Favorite Tracks"), .tracks),
    ]

    private static let columns = [GridItem(.flexible(), spacing: HomeTiles.gap), GridItem(.flexible(), spacing: HomeTiles.gap)]

    private func quickAction(_ action: QuickAction) -> some View {
        QuickActionButton(action: action) {
            do {
                try await PhoneConnection.shared.runQuickAction(action.index, action: action.action)
                onPlay()
            } catch {
                PhoneMessage.show(error)
            }
        }
    }

    var body: some View {
        homeStack
            // Home's own screen has buttons on both sides (clock centred); a page opened from it has the clock right.
            .clockPlace(path.isEmpty ? .underCentredClock : .underClockOnRight)
    }

    private var homeStack: some View {
        LibraryNavigationStack(path: $path) {
            // A List like the other pages, for watchOS's shrinking rows at the screen edges.
            List {
                Group {
                    if let actions = sections?.actions ?? QuickAction.cached, !actions.isEmpty {
                        // One row, so the tiles keep their gaps; it shrinks at the screen edges as one block.
                        LazyVGrid(columns: Self.columns, spacing: HomeTiles.gap) {
                            ForEach(actions) { action in quickAction(action) }
                        }
                        .widenToCardEdge()
                        .padding(.top, HomeTiles.topPadding)
                        .clearListRow()
                    } else if sections == nil {
                        // Wait for cached or fetched actions to avoid briefly showing a different button.
                        LazyVGrid(columns: Self.columns, spacing: HomeTiles.gap) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: HomeTiles.cornerRadius)
                                    .fill(Color.finampBlue.opacity(0.08))
                                    .frame(minHeight: HomeTiles.minHeight)
                            }
                        }
                        .clearListRow()
                    } else {
                        Button {
                            Task {
                                do {
                                    try await PhoneConnection.shared.shuffleAll()
                                    onPlay()
                                } catch {
                                    PhoneMessage.show(error)
                                }
                            }
                        } label: {
                            Label {
                                Text("Shuffle all")
                            } icon: {
                                FinampIcon(systemName: "shuffle", size: 18)
                            }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.finampGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .clearListRow()
                    }

                    if let sections {
                        HomeSection(title: String(localized: "Recently Played"), items: sections.recent) { item in
                            NavigationLink(value: item.kind == "artists"
                                ? LibraryDestination.artistAlbums(item)
                                : LibraryDestination.tracks(item, type: item.kind)) {
                                HomeCard(item: item, circular: item.kind == "artists")
                            }
                        }
                        HeadedSection(title: String(localized: "Favorites")) {
                            ForEach(Self.favoriteCards, id: \.title) { card in
                                NavigationLink(value: card.destination) {
                                    HomeCard(
                                        item: LibraryItem(id: card.destination.screenKey, name: card.title, subtitle: "", artworkKey: ""),
                                        circular: card.kind == .artists,
                                        favorites: true
                                    )
                                }
                                .buttonStyle(.plain)
                                .clearListRowReportingEdge()
                            }
                        }
                        HomeSection(title: String(localized: "Newly Added Albums"), items: sections.newAlbums) { album in
                            NavigationLink(value: LibraryDestination.tracks(album, type: "albums")) {
                                HomeCard(item: album)
                            }
                        }
                    } else if let error {
                        RetryView(message: error, inList: true) { await reload() }
                            .clearListRow()
                    } else {
                        SkeletonHomeCards()
                    }
                }
            }
            .cardList()
            .libraryDestinations(onPlay: onPlay)
            .themedBackground()
            // Buttons on both sides make watchOS centre the clock.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        FinampLogoTile()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // watchOS's input sheet supplies text only on submit.
                    TextFieldLink(prompt: Text("Search")) {
                        UpperIcon(systemName: "magnifyingglass")
                    } onSubmit: { text in
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { path = LibraryPath.opening(.search(trimmed), in: path) }
                    }
                    .upperButtonStyle()
                    .accessibilityLabel("Search")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .phoneMessageAlert()
                .phoneActivityIndicator()
                .presentationBackground(Color.appBackground)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active { Task { await reload() } }
        }

        .onReceive(NotificationCenter.default.publisher(for: .phoneBecameReachable)) { _ in
            if isActive && sections == nil { Task { await reload(quiet: true) } }
        }
    }

    // Retain current sections during reload. `quiet`: the phone came back in reach, not a tap.
    private func reload(quiet: Bool = false) async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        do {
            let home = try await PhoneConnection.shared.home(quiet: quiet)
            sections = home
            QuickAction.cached = home.actions
            error = nil
        } catch {
            if sections == nil { self.error = error.localizedDescription }
        }
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    let run: () async -> Void

    // Every title on two lines, split at the space nearest its middle ("Shuffle\nTracks"); the words come from Finamp in
    // the phone's language.
    private var displayTitle: String {
        let title = action.title
        let middle = title.count / 2
        let spaces = title.indices.filter { title[$0] == " " }
        guard let split = spaces.min(by: {
            abs(title.distance(from: title.startIndex, to: $0) - middle) < abs(title.distance(from: title.startIndex, to: $1) - middle)
        }) else { return title }
        return title.replacingCharacters(in: split...split, with: "\n")
    }

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            VStack(spacing: HomeTiles.iconToLabel) {
                FinampIcon(systemName: action.systemImage, size: HomeTiles.iconSize)
                    .font(.body.weight(.semibold))
                    .fixedIconSize()
                    .foregroundStyle(Color.finampBlue)
                Text(displayTitle)
                    .font(.caption2)
                    .foregroundStyle(Color.fgPrimary)
                    // Two lines kept for a one-line title, so every tile's icon sits at the same height.
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .padding(HomeTiles.padding)
            .frame(maxWidth: .infinity, minHeight: HomeTiles.minHeight)
            .background(Color.finampBlue.opacity(0.18), in: RoundedRectangle(cornerRadius: HomeTiles.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}

struct HomeSection<Card: View>: View {
    let title: String
    let items: [LibraryItem]
    @ViewBuilder let card: (LibraryItem) -> Card

    var body: some View {
        if !items.isEmpty {
            HeadedSection(title: title) {
                ForEach(items) { item in
                    card(item).buttonStyle(.plain).clearListRowReportingEdge()
                }
            }
        }
    }
}

// A Home, search or playlist-menu card: a cover (or the Favorites logo) and the name, on the card background (`Cards`);
// in the playlist menu also a line under the name (the track count, as Finamp's) and a state icon at the end.
struct HomeCard: View {
    let item: LibraryItem
    var circular = false
    // A Favorites card: the Favorites cover instead of the item's, in `favoritesTint` (the accent if nil).
    var favorites = false
    var favoritesTint: Color? = nil
    var detail: String? = nil
    // An icon at the end of the card, following the name's text (`PageHeader.heartSize` at Large).
    var stateIcon: String? = nil
    @ScaledMetric(relativeTo: .headline) private var stateIconSize = PageHeader.heartSize

    var body: some View {
        HStack(spacing: Cards.homeCoverToTitle) {
            Group {
                if favorites {
                    FavoritesLogo(circular: circular, tint: favoritesTint ?? .finampBlue)
                } else {
                    CoverView(item: item, circular: circular)
                }
            }
            .containerRelativeFrame(.horizontal) { width, _ in width * Cards.homeCoverShare }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(.headline.weight(Cards.homeTitleWeight))
                    .lineLimit(2)
                if let detail {
                    // As the cover rows' subtitle.
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let stateIcon {
                Image(stateIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: stateIconSize, height: stateIconSize)
            }
        }
        .homeCardBackground()
    }
}

struct SearchResultsView: View {
    let query: String
    let onPlay: () -> Void

    @State private var results: SearchResults?
    @State private var error: String?

    var body: some View {
        Group {
            if let results {
                if results.isEmpty {
                    Text("No results for “\(query)”")
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    // A List like the other pages, for watchOS's shrinking rows and its own row backgrounds.
                    List {
                        Group {
                            HomeSection(title: String(localized: "Artists"), items: results.artists) { artist in
                                NavigationLink(value: LibraryDestination.artistAlbums(artist)) {
                                    HomeCard(item: artist, circular: true)
                                }
                            }
                            HomeSection(title: String(localized: "Performing Artists"), items: results.performingArtists) { artist in
                                NavigationLink(value: LibraryDestination.artistAlbums(artist)) {
                                    HomeCard(item: artist, circular: true)
                                }
                            }
                            HomeSection(title: String(localized: "Albums"), items: results.albums) { album in
                                NavigationLink(value: LibraryDestination.tracks(album, type: "albums")) {
                                    HomeCard(item: album)
                                }
                            }
                            HomeSection(title: String(localized: "Playlists"), items: results.playlists) { playlist in
                                NavigationLink(value: LibraryDestination.tracks(playlist, type: "playlists")) {
                                    HomeCard(item: playlist)
                                }
                            }
                            HomeSection(title: String(localized: "Tracks"), items: results.tracks) { track in
                                TrackRow(
                                    track: track,
                                    onFavorite: { Task { await FavoriteOverrides.shared.toggle(track) } },
                                    favorite: FavoriteOverrides.shared.value(for: track),
                                    onTap: { Task { await play(track) } }
                                )
                                .cardRow()
                            }
                        }
                    }
                    .cardList()
                }
            } else if let error {
                RetryView(message: error) { await load() }
            } else {
                List { SkeletonTrackRows(count: 5, hearts: true) }
                    .cardList()
            }
        }
        // The query in quotes, as in "No results for “…”".
        .navigationTitle(Text(verbatim: "“\(query)”"))
        .task { if results == nil { await load() } }
    }

    private func load() async {
        error = nil
        do {
            results = try await PhoneConnection.shared.search(query)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func play(_ track: LibraryItem) async {
        do {
            try await PhoneConnection.shared.play("search", startId: track.id, extra: ["query": query])
            onPlay()
        } catch {
            self.error = error.localizedDescription
            results = nil
        }
    }
}

// The Favorites cover, as Finamp's (its playlist menu's Favorites tile): Tabler's heart in white on `tint`, the accent
// by default and the track's cover colour in the playlist menu, as Finamp themes it (`FavoritesCover`); round for
// Favorite Artists.
struct FavoritesLogo: View {
    var circular = false
    var tint: Color = .finampBlue

    var body: some View {
        Rectangle()
            .fill(tint.opacity(FavoritesCover.fillOpacity))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    Image("tabler-heart")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .frame(width: geometry.size.width * FavoritesCover.iconShare)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipShape(circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: FavoritesCover.cornerRadius)))
            .accessibilityHidden(true)
    }
}
