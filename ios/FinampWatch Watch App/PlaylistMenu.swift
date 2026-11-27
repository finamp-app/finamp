import SwiftUI

// A track's heart, as Finamp's (`add_to_playlist_button.dart`): with Finamp's "prefer adding to favourites over
// playlists" off (its default) a tap opens the playlist menu and a long press likes; on, the other way round. Every
// track heart uses this (track rows, Playback, the queue's track); album, playlist and artist hearts only like, as in
// Finamp.
extension View {
    // On a view that already has its tap area and shape (`iconTapArea`), which this keeps.
    func trackHeart(_ track: LibraryItem, like: @escaping () -> Void) -> some View {
        modifier(TrackHeart(track: track, like: like))
    }

    // Where the playlist menu opens from: the app's pages, and every sheet a track heart can be on.
    func playlistMenuHost() -> some View { modifier(PlaylistMenuHost()) }
}

private struct TrackHeart: ViewModifier {
    let track: LibraryItem
    let like: () -> Void
    @Environment(\.openPlaylistMenu) private var open
    private var settings: PhoneSettings { .shared }

    private func openMenu() { open(track) }

    func body(content: Content) -> some View {
        content
            .onTapGesture { settings.preferFavorites ? like() : openMenu() }
            .onLongPressGesture { settings.preferFavorites ? openMenu() : like() }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("Add to playlist")) { openMenu() }
    }
}

extension EnvironmentValues {
    // Opens the playlist menu from the nearest host (`playlistMenuHost()`): a sheet over the page, or over a sheet, since
    // watchOS shows a sheet only from the view in front.
    @Entry var openPlaylistMenu: (LibraryItem) -> Void = { _ in }
}

private struct PlaylistMenuHost: ViewModifier {
    @State private var track: LibraryItem?

    func body(content: Content) -> some View {
        content
            .environment(\.openPlaylistMenu) { track = $0 }
            .sheet(item: $track) { track in
                PlaylistMenu(track: track)
                    .phoneMessageAlert()
                    .phoneActivityIndicator()
            }
    }
}

// Finamp's playlist menu for one track (`playlist_actions_menu.dart`), over the track's cover blurred as Finamp's player
// background: its heart, then every playlist; a tap adds the track to a playlist or takes it out.
struct PlaylistMenu: View {
    let track: LibraryItem

    @State private var load = ListState.loading
    // Playlists known to hold the track, and those whose state is known (Finamp doesn't look them up until a tap).
    @State private var included: Set<String> = []
    @State private var known: Set<String> = []
    @State private var busy: Set<String> = []
    // Finamp's menu shows each playlist's track count; here Favorites shows its count too. The counts as loaded and
    // what the track was in at load: a toggle moves a count by one, as Finamp's reloaded count does.
    @State private var loadedIncluded: Set<String> = []
    @State private var loadedFavorite = false
    @State private var favoritesCount: Int?
    // The track's cover colour, which Finamp themes the menu with (the Favorites tile).
    @State private var tint: Color?
    private var favorites: FavoriteOverrides { .shared }

    var body: some View {
        Group {
            switch load {
            case .loading:
                List { SkeletonHomeCards() }
                    .cardList()
            case .failed(let message):
                RetryView(message: message) { await reload() }
            case .loaded(let playlists):
                List {
                    Group {
                        Button { Task { await favorites.toggle(track) } } label: {
                            HomeCard(
                                item: LibraryItem(id: "favorites", name: String(localized: "Favorites"), subtitle: "", artworkKey: ""),
                                favorites: true,
                                favoritesTint: tint,
                                detail: favoritesCount.map { FinampFormat.tracks(FinampFormat.adjusted($0, by: change(favorites.value(for: track), loadedFavorite))) },
                                stateIcon: favorites.value(for: track) ? "material-favorite" : "material-favorite-border"
                            )
                        }
                        if !playlists.isEmpty {
                            HeadedSection(title: String(localized: "Add items to a playlist")) {
                                ForEach(playlists) { playlist in
                                    Button { Task { await toggle(playlist) } } label: {
                                        HomeCard(item: playlist, detail: trackCount(playlist), stateIcon: stateIcon(playlist))
                                    }
                                    .disabled(busy.contains(playlist.id))
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .clearListRow()
                }
                .cardList()
            }
        }
        .navigationTitle(track.name)
        .presentationBackground { BlurredCover(track: track) }
        .task { if case .loading = load { await reload() } }
    }

    // Finamp's icons: a filled check when the playlist holds the track, a plus when it doesn't, a dashed plus when
    // that isn't known.
    private func stateIcon(_ playlist: LibraryItem) -> String {
        if included.contains(playlist.id) { return "tabler-circle-check-filled" }
        return known.contains(playlist.id) ? "tabler-circle-plus" : "tabler-circle-dashed-plus"
    }

    private func trackCount(_ playlist: LibraryItem) -> String {
        FinampFormat.tracks(FinampFormat.adjusted(playlist.trackCount, by: change(included.contains(playlist.id), loadedIncluded.contains(playlist.id))))
    }

    private func change(_ now: Bool, _ loaded: Bool) -> Int { now == loaded ? 0 : (now ? 1 : -1) }

    private func reload() async {
        load = .loading
        do {
            async let count = try? PhoneConnection.shared.favoritesCount()
            let menu = try await PhoneConnection.shared.playlistMenu(track.id)
            FavoriteOverrides.shared.phoneReported(track.id, menu.favorite)
            included = menu.included
            known = menu.included
            loadedIncluded = menu.included
            loadedFavorite = menu.favorite
            tint = menu.color.map { Color(argb: $0) }
            favoritesCount = await count
            load = .loaded(menu.playlists)
        } catch {
            load = .failed(error.localizedDescription)
        }
    }

    private func toggle(_ playlist: LibraryItem) async {
        busy.insert(playlist.id)
        defer { busy.remove(playlist.id) }
        do {
            let holds = try await PhoneConnection.shared.playlistToggle(track.id, playlistId: playlist.id, add: !included.contains(playlist.id))
            if holds { included.insert(playlist.id) } else { included.remove(playlist.id) }
            known.insert(playlist.id)
            PlaylistEdits.shared.changed(playlist.id)
        } catch {
            PhoneMessage.show(error)
        }
    }
}

// The playlists the menu changed, counted per playlist, so an open page of one reloads (`CollectionView`).
@MainActor @Observable
final class PlaylistEdits {
    static let shared = PlaylistEdits()
    private(set) var edits: [String: Int] = [:]

    func changed(_ id: String) { edits[id, default: 0] += 1 }
}

// The track's cover filling the screen behind the menu, blurred and darkened (`PlaylistMenuLayout`); the app's background
// while there is no cover.
private struct BlurredCover: View {
    let track: LibraryItem
    @State private var image: UIImage?

    var body: some View {
        // As Playback's cover: an overlay fills the whole screen and clips the square cover, top to bottom.
        Color.appBackground
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .overlay(Rectangle().fill(.ultraThinMaterial))
                        .overlay(Color.black.opacity(PlaylistMenuLayout.coverShade))
                }
            }
            .clipped()
            .ignoresSafeArea()
        .task(id: track.artworkKey) {
            guard !track.artworkKey.isEmpty else { return }
            image = await ArtworkStore.shared.image(for: track, size: ArtworkStore.screenPixels)
        }
    }
}
