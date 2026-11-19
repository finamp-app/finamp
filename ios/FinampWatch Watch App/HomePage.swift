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
                PhoneMessage.shared.text = error.localizedDescription
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
                                    PhoneMessage.shared.text = error.localizedDescription
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
                        SectionHeader(title: String(localized: "Favorites"))
                            .keepsWatchOSRowHeight()
                            .clearListRowReportingEdge()
                        ForEach(Self.favoriteCards, id: \.title) { card in
                            NavigationLink(value: card.destination) {
                                HomeCard(
                                    item: LibraryItem(id: card.destination.screenKey, name: card.title, subtitle: "", artworkKey: ""),
                                    circular: card.kind == .artists,
                                    favoritesSymbol: card.kind.placeholderSymbol
                                )
                            }
                            .buttonStyle(.plain)
                            .clearListRow()
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

    // "Surprise Me" on two lines like the other tiles' titles; the words come from Finamp in the phone's language.
    private var displayTitle: String {
        action.action == "surpriseMe" ? action.title.replacingOccurrences(of: " ", with: "\n") : action.title
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
            SectionHeader(title: title)
                .keepsWatchOSRowHeight()
                .clearListRowReportingEdge()
            ForEach(items) { item in
                card(item).buttonStyle(.plain).clearListRow()
            }
        }
    }
}

// Left, in line with the covers and rows below it (Finamp's section headings are left-aligned).
struct SectionHeader: View {
    let title: String
    var alignment: Alignment = .leading

    var body: some View {
        Text(title.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.fgSecondary)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.top, PageHeader.sectionHeaderTop)
    }
}

// A Home or search card: a cover (or the Favorites logo) and the name, on the card background (`Cards`).
struct HomeCard: View {
    let item: LibraryItem
    var circular = false
    // Set for a Favorites card: its logo tile instead of a cover.
    var favoritesSymbol: String? = nil

    var body: some View {
        HStack(spacing: Cards.homeCoverToTitle) {
            Group {
                if let favoritesSymbol {
                    FavoritesLogo(symbol: favoritesSymbol, circular: circular)
                } else {
                    CoverView(item: item, circular: circular)
                }
            }
            .containerRelativeFrame(.horizontal) { width, _ in width * Cards.homeCoverShare }
            Text(item.name)
                .font(.headline.weight(Cards.homeTitleWeight))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .navigationTitle(query)
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

struct FavoritesLogo: View {
    let symbol: String
    var circular = false

    var body: some View {
        Rectangle()
            .fill(.finampGradient)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    Image(systemName: symbol)
                        .font(.system(size: geometry.size.width * 0.4))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipShape(circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
            .overlay(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    let side = geometry.size.width * 0.34
                    Image(systemName: "heart.fill")
                        .font(.system(size: side * 0.55, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: side, height: side)
                        .background(Color.finampPurple, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: side * 0.15, y: side * 0.15)
                }
            }
            .accessibilityHidden(true)
    }
}
