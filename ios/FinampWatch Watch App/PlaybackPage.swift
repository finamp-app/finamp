import SwiftUI
import WatchKit

// Phone playback state with local extrapolation.
struct NowPlaying: Equatable {
    var hasTrack = false
    var id = ""
    var title = ""
    var artist = ""
    var artworkKey = ""
    var artworkURL = ""
    var blurHash = ""
    var albumID = ""
    var album = ""
    var albumArtist = ""
    var albumArtistID = ""
    var artists: [LibraryItem] = []
    // Finamp's player feature chips, as the user configured them ("E" is the explicit chip).
    var features: [String] = []
    var duration: Double = 0
    var position: Double = 0
    var updatedAt = Date()
    var playing = false
    // Playing and ready; stays false while loading or buffering.
    var advancing = false
    var loop = "none"
    var shuffled = false
    var radio = false
    var radioAvailable = false
    var favorite = false
    var upNext: [LibraryItem] = []

    func position(at date: Date) -> Double {
        let elapsed = advancing ? date.timeIntervalSince(updatedAt) : 0
        return min(max(position + elapsed, 0), duration)
    }
}

@Observable
final class NowPlayingStore {
    static let shared = NowPlayingStore()

    var nowPlaying = NowPlaying()
    // When now playing last arrived, pushed or requested.
    @ObservationIgnored private(set) var receivedAt = Date.distantPast

    func update(from state: [String: Any]) {
        receivedAt = .now
        ThemeStore.shared.apply(state["theme"])
        nowPlaying = NowPlaying(
            hasTrack: state["hasTrack"] as? Bool ?? false,
            id: state["id"] as? String ?? "",
            title: state["title"] as? String ?? "",
            artist: state["artist"] as? String ?? "",
            artworkKey: state["artworkKey"] as? String ?? "",
            artworkURL: state["artworkUrl"] as? String ?? "",
            blurHash: state["blurHash"] as? String ?? "",
            albumID: state["albumId"] as? String ?? "",
            album: state["album"] as? String ?? "",
            albumArtist: state["albumArtist"] as? String ?? "",
            albumArtistID: state["albumArtistId"] as? String ?? "",
            artists: LibraryItem.artists(from: state["artists"]),
            features: state["features"] as? [String] ?? [],
            duration: state["duration"] as? Double ?? 0,
            position: state["position"] as? Double ?? 0,
            updatedAt: Date(timeIntervalSince1970: state["updatedAt"] as? Double ?? Date().timeIntervalSince1970),
            playing: state["playing"] as? Bool ?? false,
            advancing: state["advancing"] as? Bool ?? false,
            loop: state["loop"] as? String ?? "none",
            shuffled: state["shuffled"] as? Bool ?? false,
            radio: state["radio"] as? Bool ?? false,
            radioAvailable: state["radioAvailable"] as? Bool ?? false,
            favorite: state["favorite"] as? Bool ?? false,
            upNext: (state["upNext"] as? [[String: Any]] ?? []).map { row in
                LibraryItem(
                    id: row["id"] as? String ?? "",
                    name: "",
                    subtitle: "",
                    artworkKey: row["artworkKey"] as? String ?? "",
                    artworkURL: row["artworkUrl"] as? String ?? ""
                )
            }
        )
        if nowPlaying.hasTrack, let favorite = state["favorite"] as? Bool {
            FavoriteOverrides.shared.phoneReported(nowPlaying.id, favorite)
        }
    }
}

struct PlaybackPage: View {
    let isActive: Bool

    @State private var store = NowPlayingStore.shared
    @State private var artwork: UIImage?
    @State private var artworkFor = ""
    // Retain album artwork while track-specific cover loads.
    @State private var artworkAlbum = ""
    @State private var showSystemPlayer = false
    @State private var showQueue = false
    // The bar's position (0…1) while it's being dragged.
    @State private var scrub: Double?
    @State private var crownVolume = PhoneVolume.shared.value ?? 1
    @State private var showVolume = false
    @State private var hideVolume: Task<Void, Never>?

    @Environment(\.fontResolutionContext) private var fontContext
    private var titleSize: CGFloat { TextSize.current(.title3, in: fontContext) * 0.9 }
    private var smallSize: CGFloat { 10 * TextSize.current(.caption2, in: fontContext) / TextSize.atLarge(.caption2) }

    private var nowPlaying: NowPlaying { store.nowPlaying }


    private var currentCover: LibraryItem {
        LibraryItem(
            id: nowPlaying.id,
            name: nowPlaying.title,
            subtitle: "",
            artworkKey: nowPlaying.artworkKey,
            artworkURL: nowPlaying.artworkURL
        )
    }

    private var artworkPixels: Int {
        let device = WKInterfaceDevice.current()
        let pixels = max(device.screenBounds.width, device.screenBounds.height) * device.screenScale
        return Int((pixels / 20).rounded(.up)) * 20
    }

    @State private var path: [LibraryDestination] = []

    var body: some View {
        LibraryNavigationStack(path: $path) {
            page
                .libraryDestinations(onPlay: { path = [] })
                .themedBackground()
        }
        // Attach sheets to the stack: page redraws on playback updates would present them again.
        // Override watchOS's dark sheet background for the light theme.
        .sheet(isPresented: $showSystemPlayer) {
            OutputSheet()
                .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $showQueue) {
            QueueView(onOpenArtist: { artist in
                showQueue = false
                path = LibraryPath.opening(.artistAlbums(artist), in: path)
            })
                .presentationBackground(Color.appBackground)
        }
    }

    private func openAlbum() {
        guard nowPlaying.hasTrack, !nowPlaying.albumID.isEmpty else { return }
        let album = LibraryItem(
            id: nowPlaying.albumID,
            name: nowPlaying.album,
            subtitle: nowPlaying.albumArtist,
            artworkKey: nowPlaying.artworkKey,
            artworkURL: nowPlaying.artworkURL,
            artistID: nowPlaying.albumArtistID
        )
        path = LibraryPath.opening(.tracks(album, type: "albums"), in: path)
    }

    private var page: some View {
        ZStack {
            background
            if nowPlaying.hasTrack {
                controls
                    .phoneVolumeCrown($crownVolume, enabled: isActive) {
                        showVolume = true
                        hideVolume?.cancel()
                        hideVolume = Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            if !Task.isCancelled { showVolume = false }
                        }
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .fixedIconSize()
                        .foregroundStyle(.finampGradient)
                    Text("Nothing playing")
                        .font(.headline)
                    Text("Pick something on the other pages")
                        .font(.caption2)
                        .foregroundStyle(Color.fgSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openAlbum() }
        // Toolbar items on both sides make watchOS centre the clock.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSystemPlayer = true
                } label: {
                    UpperIcon(systemName: "hifispeaker")
                }
                .upperButtonStyle()
                .accessibilityLabel("Output and Volume")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQueue = true
                } label: {
                    UpperIcon(systemName: "list.bullet")
                }
                .upperButtonStyle()
                .accessibilityLabel("Queue")
                .disabled(!nowPlaying.hasTrack)
            }
        }
        .task(id: nowPlaying.artworkKey) {
            guard !nowPlaying.artworkKey.isEmpty else {
                artwork = nil
                return
            }
            let key = nowPlaying.artworkKey
            let album = nowPlaying.albumID
            let loaded = await ArtworkStore.shared.image(for: currentCover, size: artworkPixels)
            // A slower load for an earlier track must not replace the current one's cover
            guard !Task.isCancelled, key == nowPlaying.artworkKey else { return }
            withAnimation(.easeIn(duration: 0.7)) {
                artwork = loaded
                artworkFor = key
                artworkAlbum = album
            }
        }
        // Preload upcoming covers to show them immediately on track change.
        .task(id: isActive ? nowPlaying.upNext.map(\.artworkKey) : []) {
            guard isActive else { return }
            if !nowPlaying.artworkKey.isEmpty {
                _ = await ArtworkStore.shared.image(for: currentCover, size: artworkPixels)
            }
            for next in nowPlaying.upNext where !next.artworkKey.isEmpty && !Task.isCancelled {
                _ = await ArtworkStore.shared.image(for: next, size: artworkPixels)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active { Task { try? await PhoneConnection.shared.refreshNowPlaying() } }
        }
        // Pushes are the normal path; if none arrive, ask, so the page can't go stale while it's on screen
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if Date.now.timeIntervalSince(store.receivedAt) >= 10 {
                    try? await PhoneConnection.shared.refreshNowPlaying()
                }
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        let current = artworkFor == nowPlaying.artworkKey ? artwork : nil
        let sameAlbum = !nowPlaying.albumID.isEmpty && artworkAlbum == nowPlaying.albumID ? artwork : nil
        if let artwork = current ?? sameAlbum ?? BlurHash.image(nowPlaying.blurHash) ?? artwork {
            // An overlay clips the square cover without widening the page on taller screens.
            Color.clear
                .overlay {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.15), .black.opacity(0.55), .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
        } else {
            // Dark in both themes: this page's text is always white
            LinearGradient(
                colors: [Color.finampPurple.opacity(0.45), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // One rule for every watch and text size: the gaps shrink from 9 to 3 pt when the screen is short, and when even
    // that doesn't fit, the feature chips are dropped first.
    private var controls: some View {
        ViewThatFits(in: .vertical) {
            controlsStack(showChips: true)
            controlsStack(showChips: false)
        }
        .padding(.horizontal, 6)
        // Light text over the darkened cover in either theme
        .foregroundStyle(.white)
        .padding(.bottom, Self.bottomGap)
        .ignoresSafeArea(edges: .bottom)
    }

    // Show the new position at once; restore it and say why if the phone refuses.
    private func seek(toFraction fraction: Double) {
        let target = fraction * nowPlaying.duration
        let before = store.nowPlaying
        store.nowPlaying.position = target
        store.nowPlaying.updatedAt = .now
        scrub = nil
        Task {
            do {
                try await PhoneConnection.shared.seek(to: target)
            } catch {
                if store.nowPlaying.id == before.id { store.nowPlaying = before }
                PhoneMessage.shared.text = error.localizedDescription
            }
        }
    }

    private var flexibleGap: some View {
        Spacer(minLength: 3).frame(maxHeight: 9)
    }

    // The heart's 34 pt plus the 6 pt gap it had in its row.
    private static let heartSpace: CGFloat = 40

    // The heart sits beside the artist line, bottom-aligned, as an overlay so it doesn't join the stack's layout.
    private var heartButton: some View {
        Button {
            // Capture track ID before sending; phone favourite state is authoritative.
            let id = nowPlaying.id
            let new = !nowPlaying.favorite
            store.nowPlaying.favorite = new
            Task {
                do {
                    let result = try await PhoneConnection.shared.setFavorite(id, new)
                    if store.nowPlaying.id == id { store.nowPlaying.favorite = result }
                    FavoriteOverrides.shared.phoneReported(id, result)
                } catch {
                    if store.nowPlaying.id == id { store.nowPlaying.favorite = !new }
                    PhoneMessage.shared.text = error.localizedDescription
                }
            }
        } label: {
            FavoriteHeart(filled: nowPlaying.favorite, size: 26)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nowPlaying.favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
    }

    private func controlsStack(showChips: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            // Title and artist are direct members of this stack, so their gap and the next one share space evenly.
            Marquee {
                Text(nowPlaying.title)
                    .font(.system(size: titleSize))
                    .lineLimit(1)
            }
            .padding(.trailing, Self.heartSpace)
            flexibleGap
            artistLine
                .padding(.trailing, Self.heartSpace)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottomTrailing) { heartButton }

            flexibleGap
            // Finamp's player order: feature chips, then the bar, then the times under it.
            VStack(spacing: 6) {
                if showVolume {
                    Label("Finamp volume \(Int((crownVolume * 100).rounded()))%", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: smallSize))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                } else if showChips, !nowPlaying.features.isEmpty {
                    featureChips
                }
                if !showVolume, let lowered = PhoneVolume.shared.lowered {
                    Label("Finamp volume \(lowered)%", systemImage: "speaker.wave.1.fill")
                        .font(.system(size: smallSize))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
                // Ticks every second only while the page is on screen and the watch is raised
                TimelineView(.periodic(from: .now, by: isActive ? 1 : 60)) { context in
                    // While dragging, the times show where the release will seek to, as in Finamp.
                    let position = scrub.map { $0 * nowPlaying.duration } ?? nowPlaying.position(at: context.date)
                    let canSeek = nowPlaying.hasTrack && nowPlaying.duration > 0
                    VStack(spacing: 3) {
                        ProgressLine(
                            fraction: nowPlaying.duration > 0 ? position / nowPlaying.duration : 0,
                            dragging: scrub != nil,
                            onScrub: canSeek ? { scrub = $0 } : nil,
                            onSeek: canSeek ? { seek(toFraction: $0) } : nil
                        )
                        HStack {
                            Text(formatDuration(position))
                            Spacer(minLength: 0)
                            Text("-" + formatDuration(nowPlaying.duration - position))
                        }
                        .font(.system(size: smallSize).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }

            flexibleGap
            // Flexible gaps let transport controls fit on 40 mm watches.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                transportButton("tabler-player-skip-back", label: "Previous", action: "previous")
                Spacer(minLength: 0).frame(maxWidth: 14)
                Button {
                    // Preserve position while updating optimistically; restore state if the request fails.
                    let before = store.nowPlaying
                    let now = Date()
                    store.nowPlaying.position = nowPlaying.position(at: now)
                    store.nowPlaying.updatedAt = now
                    store.nowPlaying.playing.toggle()
                    store.nowPlaying.advancing = store.nowPlaying.playing
                    Task {
                        do {
                            try await PhoneConnection.shared.control("playPause")
                        } catch {
                            if store.nowPlaying.id == before.id { store.nowPlaying = before }
                        }
                    }
                } label: {
                    Image(nowPlaying.playing ? "tabler-player-pause" : "tabler-player-play")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                        .foregroundStyle(.white)
                        .frame(width: Self.playSize, height: Self.playSize)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nowPlaying.playing ? String(localized: "Pause") : String(localized: "Play"))
                Spacer(minLength: 0).frame(maxWidth: 14)
                transportButton("tabler-player-skip-forward", label: "Next", action: "next")
                Spacer(minLength: 0)
            }
        }
    }

    // Finamp's feature chips have no background: light text, 4 pt padding each side plus 4 pt spacing.
    // One line that scrolls when it doesn't fit, as Finamp's chip row scrolls sideways.
    private var featureChips: some View {
        Marquee(centered: true) {
            HStack(spacing: 12) {
                ForEach(Array(nowPlaying.features.enumerated()), id: \.offset) { _, feature in
                    if feature == "E" {
                        Image("tabler-explicit")
                            .resizable()
                            .scaledToFit()
                            .frame(width: smallSize + 3, height: smallSize + 3)
                            .accessibilityLabel("Explicit")
                    } else {
                        Text(feature)
                    }
                }
            }
            .font(.system(size: smallSize, weight: .light))
            .foregroundStyle(.white.opacity(0.75))
        }
    }

    private static let playSize: CGFloat = 48

    // Model-specific page-dot heights require different gaps below the Play button.
    private static let bottomGap: CGFloat = {
        switch Int(WKInterfaceDevice.current().screenBounds.height) {
        case 197: return 8       // 40 mm
        case 224: return 9       // 44 mm
        case 215, 223: return 11 // 41, 42 mm
        default: return 12       // 45, 46, 49 mm
        }
    }()

    private func transportButton(_ image: String, label: LocalizedStringKey, action: String) -> some View {
        Button {
            Task {
                do {
                    try await PhoneConnection.shared.control(action)
                } catch {
                    PhoneMessage.shared.text = error.localizedDescription
                }
            }
        } label: {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 31, height: 31)
                .foregroundStyle(.white)
                .frame(maxWidth: 53)
                .frame(height: Self.playSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var artistLine: some View {
        if nowPlaying.artists.isEmpty {
            Text(nowPlaying.artist)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        } else {
            Marquee {
                HStack(spacing: 6) {
                    ForEach(nowPlaying.artists) { artist in
                        Button {
                            path = LibraryPath.opening(.artistAlbums(artist), in: path)
                        } label: {
                            ArtistChip(artist: artist, textColor: .white.opacity(0.9), background: .white.opacity(0.16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Artist \(artist.name)")
                    }
                }
            }
        }
    }

}

struct QueueView: View {
    let onOpenArtist: (LibraryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var state: ListState = .loading

    var body: some View {
        List {
            // One row with its "Up Next" heading, so the first upcoming track shows below it on screen.
            QueueHeader(onOrderChange: { await load() }, onOpenArtist: onOpenArtist)
                .listRowBackground(Color.clear)
            switch state {
            case .loading:
                SkeletonTrackRows(count: 5)
                    .listRowBackground(Color.clear)
            case .failed(let message):
                RetryView(message: message) { await load() }
                    .listRowBackground(Color.clear)
            case .loaded(let tracks):
                if tracks.isEmpty {
                    Text("Nothing up next")
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                        TrackRow(track: track, onTap: {
                            Task {
                                do {
                                    try await PhoneConnection.shared.skipTo(id: track.id)
                                } catch {
                                    PhoneMessage.shared.text = error.localizedDescription
                                }
                                dismiss()
                            }
                        })
                        // Override the system's nearly white row background in the light theme.
                        .listRowBackground(TrackRowBackground(isPlaying: false))
                    }
                }
            }
        }
        .navigationTitle("Now Playing")
        .accentTitle()
        .task { await load() }
    }

    private func load() async {
        do {
            state = .loaded(try await PhoneConnection.shared.queue())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

// Radio uses the mode selected on the phone.
private struct QueueHeader: View {
    let onOrderChange: () async -> Void
    let onOpenArtist: (LibraryItem) -> Void
    private var store: NowPlayingStore { .shared }
    private var nowPlaying: NowPlaying { store.nowPlaying }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if nowPlaying.hasTrack {
                HStack(alignment: .top, spacing: 8) {
                    CoverView(
                        item: LibraryItem(
                            id: nowPlaying.id,
                            name: nowPlaying.title,
                            subtitle: "",
                            artworkKey: nowPlaying.artworkKey,
                            artworkURL: nowPlaying.artworkURL,
                            blurHash: nowPlaying.blurHash
                        )
                    )
                    // A square as tall as the title, artist and album next to it, so they read as one block and
                    // grow together with Text Size; capped so a three-line title can't take over the row.
                    .frame(width: coverSide, height: coverSide)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(nowPlaying.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.fgPrimary)
                            .lineLimit(3)
                            // The list row otherwise keeps the title to one line on small watches.
                            .fixedSize(horizontal: false, vertical: true)
                        if !nowPlaying.artists.isEmpty {
                            // A NavigationLink here would make the entire row tappable.
                            Marquee {
                                HStack(spacing: 8) {
                                    ForEach(nowPlaying.artists) { artist in
                                        ArtistChip(artist: artist)
                                            .contentShape(Rectangle())
                                            .onTapGesture { onOpenArtist(artist) }
                                            .accessibilityAddTraits(.isButton)
                                            .accessibilityLabel("Artist \(artist.name)")
                                    }
                                }
                            }
                        } else if !nowPlaying.artist.isEmpty {
                            Text(nowPlaying.artist)
                                .font(.footnote)
                                .foregroundStyle(Color.finampBlue)
                                .lineLimit(1)
                        }
                        if !nowPlaying.album.isEmpty {
                            Text(nowPlaying.album)
                                .font(.caption2)
                                .foregroundStyle(Color.fgSecondary)
                                .lineLimit(2)
                        }
                    }
                    // The cover follows a one-line version of this block (same fonts, so it grows with Text Size);
                    // measuring the real block let a wrapping title grow the cover, which wrapped the title more.
                    .background(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: "Ag").font(.headline.weight(.bold))
                            if !nowPlaying.artists.isEmpty {
                                Color.clear.frame(width: 1, height: ArtistChip.height)
                            } else if !nowPlaying.artist.isEmpty {
                                Text(verbatim: "Ag").font(.footnote)
                            }
                            if !nowPlaying.album.isEmpty { Text(verbatim: "Ag").font(.caption2) }
                        }
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            }
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                LabeledIconButton(title: orderTitle, systemImage: orderIcon, tint: orderTint, titleLines: 2, fills: false) {
                    await change(\.shuffled, to: !nowPlaying.shuffled, action: "togglePlaybackOrder")
                    await onOrderChange()
                }
                Spacer(minLength: 0)
                LabeledIconButton(title: loopTitle, systemImage: loopIcon, tint: loopTint, titleLines: 2, fills: false) {
                    guard !nowPlaying.radio else { return }
                    await change(\.loop, to: Self.nextLoop[nowPlaying.loop] ?? "all", action: "toggleLoop")
                }
                .accessibilityHint(nowPlaying.radio ? Text("Not available while radio is on") : Text(""))
                Spacer(minLength: 0)
                LabeledIconButton(
                    title: nowPlaying.radio ? "Radio" : "No\nRadio",
                    systemImage: nowPlaying.radio ? "radio" : "radio.off",
                    tint: nowPlaying.radioAvailable ? .finampBlue : Color.fgPrimary.opacity(0.3),
                    titleLines: 2,
                    fills: false
                ) {
                    await change(\.radio, to: !nowPlaying.radio, action: "toggleRadio")
                }
                Spacer(minLength: 0)
            }
            // Clear of the cover and the text above, like the album page's buttons.
            .padding(.top, 12)
            SectionHeader(title: String(localized: "Up Next"))
                .padding(.top, -6)
        }
    }

    @State private var textHeight: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    private var coverSide: CGFloat {
        let cap = rowWidth * 0.38
        guard textHeight > 0, rowWidth > 0 else { return max(rowWidth * 0.24, 1) }
        return min(textHeight, cap)
    }

    private static let nextLoop = ["all": "one", "one": "none", "none": "all"]

    // Optimistic update; restored on failure.
    private func change<Value>(_ field: WritableKeyPath<NowPlaying, Value>, to value: Value, action: String) async {
        let before = store.nowPlaying[keyPath: field]
        store.nowPlaying[keyPath: field] = value
        do {
            try await PhoneConnection.shared.control(action)
        } catch {
            store.nowPlaying[keyPath: field] = before
        }
    }

    private var loopTitle: LocalizedStringKey {
        if nowPlaying.radio { return "No\nLoop" }
        switch nowPlaying.loop {
        case "all": return "Loop\nAll"
        case "one": return "Loop\nOne"
        default: return "No\nLoop"
        }
    }

    private var loopIcon: String {
        if nowPlaying.radio { return "repeat.off" }
        switch nowPlaying.loop {
        case "all": return "repeat"
        case "one": return "repeat.1"
        default: return "repeat.off"
        }
    }

    // Accent like the album and artist pages' buttons; the label and icon show the state, dimmed only when it can't
    // be used (loop while radio is on, radio unavailable).
    private var loopTint: Color { nowPlaying.radio ? Color.fgPrimary.opacity(0.3) : .finampBlue }

    private var orderTitle: LocalizedStringKey { nowPlaying.shuffled ? "Shuffled" : "In\nOrder" }
    private var orderIcon: String { nowPlaying.shuffled ? "shuffle" : "arrow.right" }
    private var orderTint: Color { .finampBlue }
}

// iOS requires output selection on the phone; wait for volume before binding the crown.
struct OutputSheet: View {
    @State private var output: (route: String, routeType: String)?
    @State private var error: String?
    @State private var pickerMessage: LocalizedStringKey?
    @State private var showPickerMessage = false

    var body: some View {
        Group {
            if let output {
                OutputControls(route: output.route, routeType: output.routeType, initialVolume: initialVolume)
            } else if let error {
                RetryView(message: error) { await load() }
            } else {
                VStack(spacing: 10) {
                    Circle().fill(Color.listFill).frame(width: 28, height: 28)
                    SkeletonBar(widthFraction: 0.3, height: 8)
                    SkeletonBar(widthFraction: 0.45, height: 12)
                    SkeletonBar(widthFraction: 0.7, height: 6)
                }
                .skeletonPulse()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await openPicker() }
            } label: {
                Label("Choose Output", systemImage: "airplayaudio")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ThemeStore.shared.scheme?.onPrimary ?? .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isSmallWatch ? 5 : 8)
                    .background(Color.finampBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
        }
        .alert(Text(pickerMessage ?? ""), isPresented: $showPickerMessage) {
            Button("OK", role: .cancel) {}
        }
        .task { if output == nil { await load() } }
    }

    @State private var initialVolume = 1.0

    private func load() async {
        error = nil
        do {
            let loaded = try await PhoneConnection.shared.output()
            initialVolume = loaded.volume
            output = (loaded.route, loaded.routeType)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func openPicker() async {
        do {
            pickerMessage = try await PhoneConnection.shared.showOutputPicker()
                ? "Choose the output on your iPhone"
                : "Open Finamp on your iPhone to choose the output"
        } catch {
            pickerMessage = "iPhone not reachable"
        }
        showPickerMessage = true
    }
}

// Tighter spacing for 40 mm and 41 mm watches.
private let isSmallWatch = WKInterfaceDevice.current().screenBounds.height < 220

// Finamp volume multiplies with iPhone volume and has no effect during AirPlay.
@Observable
final class PhoneVolume {
    static let shared = PhoneVolume()
    var value: Double?
    var airPlay = false

    // Shown only below 100% so a lowered volume isn't forgotten.
    var lowered: Int? {
        guard let value, value < 0.995, !airPlay else { return nil }
        return Int((value * 100).rounded())
    }
}

// Initialize with the phone volume so binding the crown does not cause a jump.
private struct OutputControls: View {
    let route: String
    let routeType: String
    @State private var volume: Double
    private var phoneVolume = PhoneVolume.shared

    init(route: String, routeType: String, initialVolume: Double) {
        self.route = route
        self.routeType = routeType
        _volume = State(initialValue: initialVolume)
    }

    var body: some View {
        VStack(spacing: isSmallWatch ? 4 : 8) {
            Image(systemName: routeSymbol)
                .font(.title2)
                .fixedIconSize()
                .foregroundStyle(.finampGradient)
            Text("Playing on")
                .font(.caption2)
                .foregroundStyle(Color.fgSecondary)
            Text(route.isEmpty ? "iPhone" : route)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.caption2).fixedIconSize()
                ProgressView(value: phoneVolume.airPlay ? 1 : volume)
                    .tint(Color.finampBlue)
                Image(systemName: "speaker.wave.3.fill").font(.caption2).fixedIconSize()
            }
            .foregroundStyle(Color.fgSecondary)
            Group {
                if phoneVolume.airPlay {
                    Text("AirPlay sets the volume on the receiving device")
                } else {
                    Text("Finamp volume \(Int((volume * 100).rounded()))% · turn the crown")
                }
            }
                .font(.caption2)
                .foregroundStyle(Color.fgSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .phoneVolumeCrown($volume, showsBar: false)
    }

    private var routeSymbol: String {
        switch routeType {
        case "airPlay": return "airplayaudio"
        case "bluetoothA2dp", "bluetoothLE", "bluetoothHfp", "headphones": return "headphones"
        case "carAudio": return "car.fill"
        default: return "iphone"
        }
    }
}

extension View {
    // Bind crown to volume; disabled during AirPlay.
    func phoneVolumeCrown(
        _ volume: Binding<Double>, enabled: Bool = true, showsBar: Bool = true, onTurn: @escaping () -> Void = {}
    ) -> some View {
        modifier(PhoneVolumeCrown(volume: volume, enabled: enabled, showsBar: showsBar, onTurn: onTurn))
    }
}

private struct PhoneVolumeCrown: ViewModifier {
    @Binding var volume: Double
    let enabled: Bool
    let showsBar: Bool
    let onTurn: () -> Void
    // Ignore phone echoes briefly after crown turns.
    @State private var lastCrownChange = Date.distantPast
    @State private var applyingPhoneVolume = false
    // Use crown deltas; binding volume directly makes the scroll bar move downward as volume rises.
    @State private var crown = 500.0
    // Shown only while the crown turns: with .automatic, watchOS also flashed it when the screen was touched.
    @State private var turning = false
    @State private var hideBar: Task<Void, Never>?
    private var phoneVolume = PhoneVolume.shared

    init(volume: Binding<Double>, enabled: Bool, showsBar: Bool, onTurn: @escaping () -> Void) {
        _volume = volume
        self.enabled = enabled
        self.showsBar = showsBar
        self.onTurn = onTurn
    }

    func body(content: Content) -> some View {
        content
            .focusable(enabled && !phoneVolume.airPlay)
            .digitalCrownRotation($crown, from: 0, through: 1000, by: 0.02, sensitivity: .low, isContinuous: true,
                                  isHapticFeedbackEnabled: true)
            .onChange(of: crown) { old, new in
                let step = new - old
                // A jump means the position wrapped at an end of its range
                guard abs(step) < 1 else { return }
                turning = true
                hideBar?.cancel()
                hideBar = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    if !Task.isCancelled { turning = false }
                }
                let next = min(1, max(0, volume + step))
                if next != volume { volume = next }
            }
            .digitalCrownAccessory {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 5, height: 40)
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Color.finampBlue)
                            .frame(width: 5, height: max(5, 40 * volume))
                    }
            }
            .digitalCrownAccessory(showsBar && turning ? .visible : .hidden)
            .onChange(of: volume) { _, new in
                if applyingPhoneVolume {
                    applyingPhoneVolume = false
                    return
                }
                lastCrownChange = .now
                onTurn()
                PhoneConnection.shared.setVolume(new)
            }
            .onChange(of: phoneVolume.value) { _, new in
                guard let new, Date.now.timeIntervalSince(lastCrownChange) > 1.5, abs(new - volume) > 0.005 else { return }
                applyingPhoneVolume = true
                volume = new
            }
    }
}

struct ProgressLine: View {
    let fraction: Double
    // Dragging or tapping the bar scrubs, releasing seeks; nil keeps it display-only.
    var dragging = false
    var onScrub: ((Double) -> Void)? = nil
    var onSeek: ((Double) -> Void)? = nil
    // The release reports a location up to 20 pt from the last drag point, so seek where the dot was last shown.
    @State private var lastScrub: Double?
    private static let line: CGFloat = 3.6
    private static let dot: CGFloat = 10.8

    var body: some View {
        GeometryReader { geometry in
            let x = geometry.size.width * min(max(fraction, 0), 1)
            let at = { (location: CGPoint) in min(max(location.x / max(geometry.size.width, 1), 0), 1) }
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3)).frame(height: Self.line)
                Capsule().fill(.white).frame(width: x, height: Self.line)
                // Grows while dragging by scaling only, so the bar never shifts
                Circle().fill(.white).frame(width: Self.dot, height: Self.dot).scaleEffect(dragging ? 1.5 : 1)
                    .offset(x: x - Self.dot / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // A taller touch strip than the bar, without making the layout taller.
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged {
                        lastScrub = at($0.location)
                        onScrub?(at($0.location))
                    }
                    .onEnded {
                        onSeek?(lastScrub ?? at($0.location))
                        lastScrub = nil
                    },
                including: onSeek == nil ? .none : .all
            )
            .padding(.vertical, -8)
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(String(localized: "\(Int((min(max(fraction, 0), 1) * 100).rounded())) percent"))
        // VoiceOver seeks in 5% steps by swiping up or down
        .accessibilityAdjustableAction { direction in
            guard let onSeek else { return }
            switch direction {
            case .increment: onSeek(min(fraction + 0.05, 1))
            case .decrement: onSeek(max(fraction - 0.05, 0))
            @unknown default: break
            }
        }
    }
}

struct Marquee<Content: View>: View {
    // Centre content that fits instead of leading-aligning it.
    var centered = false
    @ViewBuilder let content: Content

    @State private var contentSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0
    // Pause scrolling while dimmed.
    @Environment(\.scenePhase) private var scenePhase

    private let gap: CGFloat = 24
    private let speed: CGFloat = 22
    private let pause: Double = 1.5

    var body: some View {
        // Overlay content must not widen the page; only its measured height affects layout.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: contentSize.height)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    content
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                    if contentSize.width > containerWidth + 1, scenePhase == .active {
                        TimelineView(.animation) { context in
                            let cycle = Double((contentSize.width + gap) / speed) + pause
                            let time = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                            HStack(spacing: gap) {
                                content
                                content
                            }
                            .fixedSize()
                            .offset(x: time < pause ? 0 : -CGFloat(time - pause) * speed)
                        }
                    } else {
                        content.fixedSize()
                            .frame(width: centered ? max(containerWidth, contentSize.width) : nil)
                    }
                }
            }
            .clipped()
    }
}
