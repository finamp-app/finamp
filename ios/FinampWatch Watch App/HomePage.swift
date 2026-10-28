import SwiftUI

/// Home quick actions, favourites and recent music.
struct HomePage: View {
    /// Loads only while this page is visible.
    let isActive: Bool
    /// Returns to playback after starting music.
    let onPlay: () -> Void

    @State private var sections: HomeSections?
    @State private var error: String?
    @State private var isReloading = false
    @State private var path: [LibraryDestination] = []
    @State private var showSettings = false

    var body: some View {
        LibraryNavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let actions = sections?.actions ?? QuickAction.cached, !actions.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                            ForEach(actions) { action in
                                QuickActionButton(action: action) {
                                    do {
                                        try await PhoneConnection.shared.runQuickAction(action.index, action: action.action)
                                        onPlay()
                                    } catch {
                                        self.error = error.localizedDescription
                                    }
                                }
                            }
                        }
                    } else if sections == nil {
                        // Wait for cached or fetched actions to avoid briefly showing a different button.
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.finampBlue.opacity(0.08))
                                    .frame(minHeight: 54)
                            }
                        }
                    } else {
                        Button {
                            Task {
                                do {
                                    try await PhoneConnection.shared.shuffleAll()
                                    onPlay()
                                } catch {
                                    self.error = error.localizedDescription
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
                    }

                    if let sections {
                        HomeSection(title: String(localized: "Recently Played"), items: sections.recent) { item in
                            NavigationLink(value: item.kind == "artists"
                                ? LibraryDestination.artistAlbums(item)
                                : LibraryDestination.tracks(item, type: item.kind)) {
                                HomeCard(
                                    item: item,
                                    placeholderSymbol: item.kind == "artists" ? LibraryKind.artists.placeholderSymbol
                                        : item.kind == "playlists" ? LibraryKind.playlists.placeholderSymbol
                                        : LibraryKind.albums.placeholderSymbol,
                                    circular: item.kind == "artists"
                                )
                            }
                        }
                        SectionHeader(title: String(localized: "Favorites"))
                        NavigationLink(value: LibraryDestination.favoriteAlbums) {
                            HomeCard(
                                item: LibraryItem(id: "favoriteAlbums", name: String(localized: "Favorite Albums"), subtitle: "", artworkKey: ""),
                                placeholderSymbol: LibraryKind.albums.placeholderSymbol,
                                favoriteBadge: true
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: LibraryDestination.favoriteArtists) {
                            HomeCard(
                                item: LibraryItem(id: "favoriteArtists", name: String(localized: "Favorite Artists"), subtitle: "", artworkKey: ""),
                                placeholderSymbol: LibraryKind.artists.placeholderSymbol,
                                circular: true,
                                favoriteBadge: true
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: LibraryDestination.favorites) {
                            HomeCard(
                                item: LibraryItem(id: "favorites", name: String(localized: "Favorite Tracks"), subtitle: "", artworkKey: ""),
                                placeholderSymbol: LibraryKind.tracks.placeholderSymbol,
                                favoriteBadge: true
                            )
                        }
                        .buttonStyle(.plain)
                        HomeSection(title: String(localized: "Newly Added Albums"), items: sections.newAlbums) { album in
                            NavigationLink(value: LibraryDestination.tracks(album, type: "albums")) {
                                HomeCard(item: album, placeholderSymbol: LibraryKind.albums.placeholderSymbol)
                            }
                        }
                    } else if let error {
                        RetryView(message: error) { await reload() }
                    } else {
                        SkeletonHomeCards()
                    }
                }
            }
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
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.fgPrimary)
                    } onSubmit: { text in
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { path = LibraryPath.opening(.search(trimmed), in: path) }
                    }
                    .accessibilityLabel("Search")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationBackground(Color.appBackground)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active { Task { await reload() } }
        }

        .onReceive(NotificationCenter.default.publisher(for: .phoneBecameReachable)) { _ in
            if isActive && sections == nil { Task { await reload() } }
        }
    }

    /// Keeps current sections visible during a reload.
    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        do {
            let home = try await PhoneConnection.shared.home()
            sections = home
            ThemeStore.shared.apply(home.theme)
            QuickAction.cached = home.actions
            error = nil
        } catch {
            if sections == nil { self.error = error.localizedDescription }
        }
    }
}

/// A Home quick action tile.
struct QuickActionButton: View {
    let action: QuickAction
    let run: () async -> Void

    var body: some View {
        Button {
            Task { await run() }
        } label: {
            VStack(spacing: 3) {
                FinampIcon(systemName: action.systemImage, size: 19)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.finampBlue)
                Text(action.title)
                    .font(.caption2)
                    .foregroundStyle(Color.fgPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 4)
            .background(Color.finampBlue.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}

/// A section header and cards, hidden when empty.
struct HomeSection<Card: View>: View {
    let title: String
    let items: [LibraryItem]
    @ViewBuilder let card: (LibraryItem) -> Card

    var body: some View {
        if !items.isEmpty {
            SectionHeader(title: title)
            ForEach(items) { item in
                card(item).buttonStyle(.plain)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.fgSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }
}

/// A Home card with a cover and title.
struct HomeCard: View {
    let item: LibraryItem
    let placeholderSymbol: String
    var circular = false
    var favoriteBadge = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if favoriteBadge {
                    FavoritesLogo(symbol: placeholderSymbol, circular: circular)
                } else {
                    CoverView(item: item, placeholderSymbol: placeholderSymbol, circular: circular)
                }
            }
            .containerRelativeFrame(.horizontal) { width, _ in width * 0.2 }
            Text(item.name)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color.listFill, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Search results grouped by item type.
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HomeSection(title: String(localized: "Artists"), items: results.artists) { artist in
                                NavigationLink(value: LibraryDestination.artistAlbums(artist)) {
                                    HomeCard(item: artist, placeholderSymbol: LibraryKind.artists.placeholderSymbol, circular: true)
                                }
                            }
                            HomeSection(title: String(localized: "Albums"), items: results.albums) { album in
                                NavigationLink(value: LibraryDestination.tracks(album, type: "albums")) {
                                    HomeCard(item: album, placeholderSymbol: LibraryKind.albums.placeholderSymbol)
                                }
                            }
                            HomeSection(title: String(localized: "Playlists"), items: results.playlists) { playlist in
                                NavigationLink(value: LibraryDestination.tracks(playlist, type: "playlists")) {
                                    HomeCard(item: playlist, placeholderSymbol: LibraryKind.playlists.placeholderSymbol)
                                }
                            }
                            HomeSection(title: String(localized: "Tracks"), items: results.tracks) { track in
                                TrackRow(
                                    track: track,
                                    onFavorite: { Task { await FavoriteOverrides.shared.toggle(track) } },
                                    favorite: FavoriteOverrides.shared.value(for: track),
                                    onTap: { Task { await play(track) } }
                                )
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(TrackRowBackground(isPlaying: false))
                            }
                        }
                    }
                }
            } else if let error {
                RetryView(message: error) { await load() }
            } else {
                ScrollView { SkeletonTrackRows(count: 5) }
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

/// A favourites list symbol with a heart badge.
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
