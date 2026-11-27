import SwiftUI

// One of the short chips the phone sends (watch_protocol.md, shortFeatures).
enum ShortChip: Equatable {
    case explicit
    case plays(String)
    case mode(String)
    // "OPUS@128", or the codec or bitrate alone
    case format(String)

    init?(_ chip: [String: Any]) {
        switch chip["type"] as? String {
        case "explicit": self = .explicit
        case "plays": self = .plays(chip["text"] as? String ?? "")
        case "mode": self = .mode(chip["mode"] as? String ?? "")
        case "format":
            let codec = chip["codec"] as? String
            let kbps = (chip["kbps"] as? NSNumber)?.intValue
            switch (codec, kbps) {
            case let (codec?, kbps?): self = .format("\(codec)@\(kbps)")
            case let (codec?, nil): self = .format(codec)
            case let (nil, kbps?): self = .format("\(kbps)")
            default: return nil
            }
        default: return nil
        }
    }
}

// Phone playback state with local extrapolation.
struct NowPlaying: Equatable {
    var hasTrack = false
    var id = ""
    // The queue entry playing (`id` is the track, the same when it's queued twice).
    var queueEntryID = ""
    var title = ""
    var artist = ""
    var artworkKey = ""
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
    // Finamp's playback speed: the position advances this many seconds per second.
    var speed: Double = 1
    var loop = "none"
    var shuffled = false
    var radio = false
    var radioAvailable = false
    var favorite = false
    var upNext: [LibraryItem] = []
    // The queue entries the queue sheet lists, in order: it reloads when they change.
    var queueEntryIDs: [String] = []
    // The colour Finamp's player takes from this track's cover; nil until the phone sends one.
    var coverColor: Color?
    // The short chips, in the order the user set Finamp's chips.
    var shortChips: [ShortChip] = []

    // The playing track as a library item, for its cover and its heart.
    var trackItem: LibraryItem { LibraryItem(id: id, name: title, subtitle: "", artworkKey: artworkKey, blurHash: blurHash) }

    func position(at date: Date) -> Double {
        let elapsed = advancing ? date.timeIntervalSince(updatedAt) * speed : 0
        return min(max(position + elapsed, 0), duration)
    }
}

@Observable
final class NowPlayingStore {
    static let shared = NowPlayingStore()

    var nowPlaying = NowPlaying()
    // When now playing last arrived, pushed or requested.
    @ObservationIgnored private(set) var receivedAt = Date.distantPast
    // The phone's time on the newest state taken. Pushes, the stored context and the complication's updates can arrive
    // out of order, and an older state would move playback back; the watch's own instant updates don't count here.
    @ObservationIgnored private var phoneTime: Double = 0

    // Optimistic; the phone's answer is authoritative.
    func toggleFavorite() {
        let id = nowPlaying.id
        let new = !nowPlaying.favorite
        nowPlaying.favorite = new
        Task {
            do {
                let result = try await PhoneConnection.shared.setFavorite(id, new)
                if nowPlaying.id == id { nowPlaying.favorite = result }
                FavoriteOverrides.shared.phoneReported(id, result)
            } catch {
                if nowPlaying.id == id { nowPlaying.favorite = !new }
                PhoneMessage.show(error)
            }
        }
    }

    func update(from state: [String: Any]) {
        if let time = state["updatedAt"] as? Double {
            if time < phoneTime {
                WatchLog.fine("older now playing dropped (\(String(format: "%.1f", phoneTime - time)) s)")
                return
            }
            phoneTime = time
        }
        receivedAt = .now
        let previous = nowPlaying
        let short = state["shortFeatures"] as? [[String: Any]] ?? []
        nowPlaying = NowPlaying(
            hasTrack: state["hasTrack"] as? Bool ?? false,
            id: state["id"] as? String ?? "",
            queueEntryID: state["queueEntryId"] as? String ?? "",
            title: state["title"] as? String ?? "",
            artist: state["artist"] as? String ?? "",
            artworkKey: state["artworkKey"] as? String ?? "",
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
            speed: state["speed"] as? Double ?? 1,
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
                    artworkKey: row["artworkKey"] as? String ?? ""
                )
            },
            queueEntryIDs: state["queueEntryIds"] as? [String] ?? [],
            coverColor: (state["coverColor"] as? NSNumber).map { Color(argb: $0.intValue) },
            shortChips: short.compactMap(ShortChip.init)
        )
        // For the log: how far the watch's own estimate was off when the phone's position arrived (same track).
        if previous.hasTrack, previous.id == nowPlaying.id, previous.advancing {
            let drift = nowPlaying.position - previous.position(at: nowPlaying.updatedAt)
            if abs(drift) > 1 { WatchLog.fine("position drift \(String(format: "%.1f", drift)) s at speed \(nowPlaying.speed)") }
        }
        if nowPlaying.hasTrack, let favorite = state["favorite"] as? Bool {
            FavoriteOverrides.shared.phoneReported(nowPlaying.id, favorite)
        }
    }
}

struct PlaybackPage: View {
    let isActive: Bool
    // Counts playback started from another page (`ContentView.showPlayer`): each one closes whatever page Playback had
    // open, so the player shows what was just started. Coming here by swiping leaves the open page as it was.
    let playStarted: Int

    @State private var store = NowPlayingStore.shared
    @State private var artwork: UIImage?
    @State private var artworkFor = ""
    // Retain album artwork while track-specific cover loads.
    @State private var artworkAlbum = ""
    // A cover that didn't load is asked for again (`ConnectionPolicy.Cover`); bumping this restarts the cover's load,
    // and the store answers from its cache when the cover arrived meanwhile.
    @State private var artworkAttempt = 0
    @State private var artworkTriedAt = Date.distantPast
    // The cover key whose last load ended without a cover.
    @State private var artworkMissingFor = ""
    @State private var showSystemPlayer = false
    @State private var showQueue = false
    // The bar's position (0…1) while it's being dragged.
    @State private var scrub: Double?
    // The cover shade's middle (`PlaybackLayout.coverShadeStops`): the bottom of the title's line on the screen. The
    // shade takes no part in the layout, so this can't loop.
    @State private var shadeMiddle: CGFloat = 0.5
    @State private var showVolume = false
    @State private var hideVolume: Task<Void, Never>?

    @Environment(\.fontResolutionContext) private var fontContext
    private var titleSize: CGFloat { TextSize.current(.title3, in: fontContext) * PlaybackLayout.titleScale }
    @ScaledMetric(relativeTo: .caption2) private var smallSize = SmallText.atLarge

    private var nowPlaying: NowPlaying { store.nowPlaying }

    @State private var path: [LibraryDestination] = []

    var body: some View {
        LibraryNavigationStack(path: $path) {
            page
                .libraryDestinations(onPlay: { path = [] })
                .onChange(of: playStarted) { path = [] }
                .themedBackground()
        }
        // Playback's own screen has buttons on both sides (clock centred); a page opened from it has the clock right.
        .clockPlace(path.isEmpty ? .underCentredClock : .underClockOnRight)
        // Attach sheets to the stack: page redraws on playback updates would present them again.
        // Finamp's background instead of watchOS's own sheet background.
        .sheet(isPresented: $showSystemPlayer) {
            OutputSheet()
                .phoneMessageAlert()
                .phoneActivityIndicator()
                .presentationBackground(Color.appBackground)
        }
        .sheet(isPresented: $showQueue) {
            QueueView(onOpenArtist: { artist in
                showQueue = false
                path = LibraryPath.opening(.artistAlbums(artist), in: path)
            })
                .playlistMenuHost()
                .phoneMessageAlert()
                .phoneActivityIndicator()
                .presentationBackground(Color.appBackground)
        }
    }

    // Like Finamp's player, fetch the album first, so its page has the release date and full totals; what now playing
    // knows if the phone can't answer.
    private func openAlbum() {
        guard nowPlaying.hasTrack, !nowPlaying.albumID.isEmpty else { return }
        let known = LibraryItem(
            id: nowPlaying.albumID,
            name: nowPlaying.album,
            subtitle: nowPlaying.albumArtist,
            artworkKey: nowPlaying.artworkKey,
            artistID: nowPlaying.albumArtistID
        )
        Task {
            let album = (try? await PhoneConnection.shared.item(known.id)) ?? known
            path = LibraryPath.opening(.tracks(album, type: "albums"), in: path)
        }
    }

    private var page: some View {
        ZStack {
            background
            if nowPlaying.hasTrack {
                controls
                    .phoneVolumeCrown(enabled: isActive) {
                        showVolume = true
                        hideVolume?.cancel()
                        hideVolume = Task {
                            try? await Task.sleep(for: .seconds(PlaybackLayout.volumeShownFor))
                            if !Task.isCancelled { showVolume = false }
                        }
                    }
            } else {
                VStack(spacing: StatusPages.spacing) {
                    StatusIcon(asset: "tabler-music", style: .largeTitle)
                    Text("Nothing playing")
                        .font(.headline)
                    Text("Pick something on the other pages")
                        .font(.caption2)
                        .foregroundStyle(Color.fgSecondary)
                        .multilineTextAlignment(.center)
                }
                .scenePadding(.horizontal)
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
        .task(id: "\(nowPlaying.artworkKey)#\(artworkAttempt)") {
            guard !nowPlaying.artworkKey.isEmpty else {
                artwork = nil
                return
            }
            artworkTriedAt = .now
            let key = nowPlaying.artworkKey
            let album = nowPlaying.albumID
            let loaded = await ArtworkStore.shared.image(for: nowPlaying.trackItem, size: ArtworkStore.screenPixels)
            // A slower load for an earlier track must not replace the current one's cover
            guard !Task.isCancelled, key == nowPlaying.artworkKey else { return }
            artworkMissingFor = loaded == nil ? key : ""
            withAnimation(.easeIn(duration: Covers.fadeIn)) {
                artwork = loaded
                artworkFor = key
                artworkAlbum = album
            }
        }
        // Preload upcoming covers to show them immediately on track change.
        .task(id: isActive ? nowPlaying.upNext.map(\.artworkKey) : []) {
            guard isActive else { return }
            if !nowPlaying.artworkKey.isEmpty {
                _ = await ArtworkStore.shared.image(for: nowPlaying.trackItem, size: ArtworkStore.screenPixels)
            }
            for next in nowPlaying.upNext where !next.artworkKey.isEmpty && !Task.isCancelled {
                _ = await ArtworkStore.shared.image(for: next, size: ArtworkStore.screenPixels)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            // Resting: no ticking or polling while dimmed, wrist down or on another page.
            WatchLog.info(active ? "playback awake" : "playback resting")
            if active {
                Task { try? await PhoneConnection.shared.refreshNowPlaying() }
                retryCoverIfMissing(after: ConnectionPolicy.Cover.retryOnWake)
            }
        }
        // Pushes are the normal path; if none arrive, ask, so the page can't go stale while it's on screen
        .task(id: isActive) {
            guard isActive else { return }
            let every = ConnectionPolicy.Playback.refreshEvery
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(every))
                if Date.now.timeIntervalSince(store.receivedAt) >= every {
                    try? await PhoneConnection.shared.refreshNowPlaying()
                }
                retryCoverIfMissing(after: ConnectionPolicy.Cover.retryEvery)
            }
        }
    }

    // Ask again for this track's cover when its last load ended without one (the phone couldn't get it or was out of
    // reach); `seconds` since the last try keeps it from repeating faster than that.
    private func retryCoverIfMissing(after seconds: TimeInterval) {
        guard isActive, !nowPlaying.artworkKey.isEmpty, artworkMissingFor == nowPlaying.artworkKey,
              Date.now.timeIntervalSince(artworkTriedAt) >= seconds
        else { return }
        WatchLog.fine("cover: asking again")
        artworkAttempt += 1
    }

    // The cover on screen: this track's, else its album's, else its BlurHash, else the previous cover.
    private var shownArtwork: UIImage? {
        let current = artworkFor == nowPlaying.artworkKey ? artwork : nil
        let sameAlbum = !nowPlaying.albumID.isEmpty && artworkAlbum == nowPlaying.albumID ? artwork : nil
        return current ?? sameAlbum ?? BlurHash.image(nowPlaying.blurHash) ?? artwork
    }

    @ViewBuilder
    private var background: some View {
        if let artwork = shownArtwork {
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
                        stops: PlaybackLayout.coverShadeStops(middle: shadeMiddle),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
        } else {
            // Always dark: this page's text is white
            LinearGradient(
                colors: [Color.finampPurple.opacity(PlaybackLayout.noCoverGradientOpacity), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // One rule for every watch and text size: the gaps shrink (`PlaybackLayout.gapMax` to `gapMin`) when the screen is
    // short, and when even that doesn't fit, the feature chips are dropped first and the gaps stay at their smallest.
    private var controls: some View {
        ViewThatFits(in: .vertical) {
            controlsStack(showChips: true)
            controlsStack(showChips: false)
        }
        // Not a list: watchOS's margin, in line with the top buttons.
        .scenePadding(.horizontal)
        // White text over the darkened cover, whatever the accent
        .foregroundStyle(.white)
        .padding(.bottom, PlaybackLayout.bottomGap)
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
                try await PhoneConnection.shared.seek(to: target, in: before.queueEntryID)
            } catch {
                if store.nowPlaying.queueEntryID == before.queueEntryID { store.nowPlaying = before }
                PhoneMessage.show(error)
            }
        }
    }

    // When the chips had to go, the screen is tight: every gap stays at its smallest, the gap above the Play button
    // too, and the room the chips leave goes above the title, so no gap grows back while the others are squeezed.
    // `share`: this gap against the others (`PlaybackLayout.timesToControlsShare`).
    @ViewBuilder
    private func gap(tight: Bool, share: CGFloat = 1) -> some View {
        if tight {
            Spacer(minLength: PlaybackLayout.gapMin * share).frame(height: PlaybackLayout.gapMin * share)
        } else {
            Spacer(minLength: PlaybackLayout.gapMin * share).frame(maxHeight: PlaybackLayout.gapMax * share)
        }
    }

    // `PlaybackLayout.heartToChip`
    @ScaledMetric(relativeTo: .footnote) private var heartSize = ArtistChips.height * PlaybackLayout.heartToChip

    private var heartButton: some View {
        FavoriteHeart(filled: nowPlaying.favorite, size: heartSize)
            .foregroundStyle(controlTint)
            .iconTapArea(heartSize)
            .trackHeart(nowPlaying.trackItem) { store.toggleFavorite() }
            .accessibilityLabel(FavoriteHeart.label(nowPlaying.favorite))
    }

    private func controlsStack(showChips: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            // Title and artist are direct members of this stack, so their gap and the next one share space evenly.
            Marquee {
                Text(nowPlaying.title)
                    .font(.system(size: titleSize, weight: PlaybackLayout.titleWeight))
                    .lineLimit(1)
            }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: {
                shadeMiddle = $0 / Margins.screenSize.height
            }
            gap(tight: !showChips)
            // The artist row (`PlaybackLayout.artistToHeart`).
            HStack(spacing: PlaybackLayout.artistToHeart) {
                artistLine
                    .frame(maxWidth: .infinity, alignment: .leading)
                heartButton
            }

            gap(tight: !showChips)
            // Finamp's player order: feature chips, then the bar, then the times under it.
            VStack(spacing: PlaybackLayout.chipsToBar) {
                if showVolume {
                    Label("Finamp volume \(FinampFormat.percent(PhoneVolume.shared.shown))%", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: smallSize))
                        .foregroundStyle(.white.opacity(PlaybackLayout.volumeOpacity))
                        .frame(maxWidth: .infinity)
                } else if showChips, showTrackInfo, shortChips ? !nowPlaying.shortChips.isEmpty : !nowPlaying.features.isEmpty {
                    if shortChips { shortFeatureChips } else { featureChips }
                }
                if !showVolume, let lowered = PhoneVolume.shared.lowered {
                    Label("Finamp volume \(lowered)%", systemImage: "speaker.wave.1.fill")
                        .font(.system(size: smallSize))
                        .foregroundStyle(.white.opacity(PlaybackLayout.loweredOpacity))
                        .frame(maxWidth: .infinity)
                }
                // Ticks every second only while the page is on screen and the watch is raised
                TimelineView(.periodic(from: .now, by: isActive ? 1 : 60)) { context in
                    // While dragging, the times show where the release will seek to, as in Finamp.
                    let position = scrub.map { $0 * nowPlaying.duration } ?? nowPlaying.position(at: context.date)
                    let canSeek = nowPlaying.hasTrack && nowPlaying.duration > 0
                    VStack(spacing: PlaybackLayout.barToTimes) {
                        ProgressLine(
                            fraction: nowPlaying.duration > 0 ? position / nowPlaying.duration : 0,
                            dragging: scrub != nil,
                            onScrub: canSeek ? { scrub = $0 } : nil,
                            onSeek: canSeek ? { seek(toFraction: $0) } : nil,
                            tint: controlTint
                        )
                        // A new track ends a drag begun on the one before, so its release can't seek the new one.
                        .id(nowPlaying.queueEntryID)
                        .onChange(of: nowPlaying.queueEntryID) { scrub = nil }
                        HStack {
                            // As Finamp's player (`progress_slider.dart`): both rounded to the second, then subtracted.
                            Text(FinampFormat.duration(position.rounded(), padded: false))
                            Spacer(minLength: 0)
                            Text("-" + FinampFormat.duration(nowPlaying.duration.rounded() - position.rounded(), padded: false))
                        }
                        .font(.system(size: smallSize).monospacedDigit())
                        .foregroundStyle(.white.opacity(PlaybackLayout.textOpacity))
                    }
                }
            }

            gap(tight: !showChips, share: PlaybackLayout.timesToControlsShare)
            // Flexible gaps let transport controls fit on 40 mm watches.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                transportButton("tabler-player-skip-back", label: "Previous", action: "previous")
                Spacer(minLength: 0).frame(maxWidth: PlaybackLayout.transportGapMax)
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
                            PhoneMessage.show(error)
                        }
                    }
                } label: {
                    Image(nowPlaying.playing ? "tabler-player-pause" : "tabler-player-play")
                        .icon(PlaybackLayout.playIconSize)
                        .foregroundStyle(controlTint)
                        .frame(width: PlaybackLayout.playSize, height: PlaybackLayout.playSize)
                        .background(
                            controlTint.opacity(PlaybackLayout.playFillOpacity),
                            in: RoundedRectangle(cornerRadius: PlaybackLayout.playCornerRadius, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nowPlaying.playing ? String(localized: "Pause") : String(localized: "Play"))
                Spacer(minLength: 0).frame(maxWidth: PlaybackLayout.transportGapMax)
                transportButton("tabler-player-skip-forward", label: "Next", action: "next")
                Spacer(minLength: 0)
            }
        }
    }

    // Finamp's feature chips have no background: light text, spaced as Finamp's chip padding and spacing add up.
    // One line that scrolls when it doesn't fit, as Finamp's chip row scrolls sideways.
    private var featureChips: some View {
        Marquee(centered: true) {
            HStack(spacing: PlaybackLayout.chipGap) {
                ForEach(Array(nowPlaying.features.enumerated()), id: \.offset) { _, feature in
                    if feature == "E" {
                        Image("tabler-explicit")
                            .icon(smallSize + PlaybackLayout.chipIconGrowth)
                            .accessibilityLabel("Explicit")
                    } else {
                        Text(feature)
                    }
                }
            }
            .font(.system(size: smallSize, weight: .light))
            .foregroundStyle(.white.opacity(PlaybackLayout.textOpacity))
        }
    }

    // Settings → Advanced Track Info (`TrackInfo`): the chips, or with Short Track Info only the explicit icon, the play
    // count, how the track plays (Finamp's icon) and codec@bitrate as in "OPUS@128", in the order of Finamp's chips.
    @AppStorage(TrackInfo.showKey) private var showTrackInfo = TrackInfo.showDefault
    @AppStorage(TrackInfo.shortKey) private var shortChips = TrackInfo.shortDefault

    // One rule for every watch and text size, as the controls' gaps: the gaps between chips shrink (`chipGap` to
    // `chipGapMin`) when the line is short of room, and when even that doesn't fit, the line scrolls like the full chips.
    private var shortFeatureChips: some View {
        ViewThatFits(in: .horizontal) {
            shortChipsRow(flexible: true)
            Marquee(centered: true) { shortChipsRow(flexible: false) }
        }
        .font(.system(size: smallSize, weight: .light))
        .foregroundStyle(.white.opacity(PlaybackLayout.textOpacity))
        .lineLimit(1)
        .frame(maxWidth: .infinity)
    }

    private func shortChipsRow(flexible: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(nowPlaying.shortChips.enumerated()), id: \.offset) { index, chip in
                if index > 0 {
                    if flexible {
                        Spacer(minLength: PlaybackLayout.chipGapMin).frame(maxWidth: PlaybackLayout.chipGap)
                    } else {
                        Color.clear.frame(width: PlaybackLayout.chipGap)
                    }
                }
                switch chip {
                case .explicit:
                    chipIcon("tabler-explicit").accessibilityLabel("Explicit")
                case .plays(let text), .format(let text):
                    Text(verbatim: text).fixedSize()
                case .mode(let mode):
                    if let icon = Self.modeIcons[mode] {
                        chipIcon(icon.asset).accessibilityLabel(Text(icon.label))
                    }
                }
            }
        }
    }

    // How the track plays, with the icons Finamp's developers chose: cloud, SD card, compress.
    private static let modeIcons: [String: (asset: String, label: LocalizedStringKey)] = [
        "direct": ("tabler-cloud", "Direct Playing"),
        "local": ("tabler-device-sd-card", "Local"),
        "transcoding": ("material-compress", "Transcoding"),
    ]

    private func chipIcon(_ asset: String) -> some View {
        Image(asset)
            .icon(smallSize + PlaybackLayout.shortChipIconGrowth)
    }

    // Temporary, until one style is chosen: controls in white or in the cover's colour as in Finamp's player, set with
    // the launch argument `-playbackStyle white|colored`; the colour by default, since a watch has no launch arguments.
    private var playbackStyle: String { UserDefaults.standard.string(forKey: "playbackStyle") ?? "colored" }
    private var controlTint: Color { playbackStyle == "white" ? .white : (nowPlaying.coverColor ?? .white) }

    private func transportButton(_ image: String, label: LocalizedStringKey, action: String) -> some View {
        Button {
            Task {
                do {
                    try await PhoneConnection.shared.control(action)
                } catch {
                    PhoneMessage.show(error)
                }
            }
        } label: {
            Image(image)
                .icon(PlaybackLayout.skipIconSize)
                .foregroundStyle(controlTint)
                .frame(maxWidth: PlaybackLayout.skipMaxWidth)
                .frame(height: PlaybackLayout.playSize)
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
                .foregroundStyle(.white.opacity(PlaybackLayout.textOpacity))
                .lineLimit(1)
        } else {
            Marquee {
                HStack(spacing: PlaybackLayout.artistChipSpacing) {
                    ForEach(nowPlaying.artists) { artist in
                        Button {
                            path = LibraryPath.opening(.artistAlbums(artist), in: path)
                        } label: {
                            ArtistChip(
                                artist: artist,
                                textColor: .white.opacity(PlaybackLayout.chipTextOpacity),
                                background: .white.opacity(PlaybackLayout.chipFillOpacity)
                            )
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
    // Set once the sheet's own first load has started; reloads after it are the phone's doing.
    @State private var followingPhone = false

    var body: some View {
        List {
            QueueHeader(onOrderChange: { await load(quiet: false) }, onOpenArtist: onOpenArtist)
                .clearListRow()
            HeadedSection(title: String(localized: "Up Next")) {
                switch state {
                case .loading:
                    SkeletonTrackRows(count: 5)
                case .failed(let message):
                    RetryView(message: message, inList: true) { await load(quiet: false) }
                        .clearListRow()
                case .loaded(let tracks):
                    if tracks.isEmpty {
                        EmptyNote(text: String(localized: "Nothing up next"), inList: true)
                            .clearListRow()
                    } else {
                        ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track, onTap: {
                                Task {
                                    do {
                                        try await PhoneConnection.shared.skipTo(id: track.id)
                                    } catch {
                                        PhoneMessage.show(error)
                                    }
                                    dismiss()
                                }
                            })
                            .cardRow()
                        }
                    }
                }
            }
        }
        .cardList()
        .navigationTitle("Now Playing")
        .accentTitle()
        // Again whenever the playing entry or the entries it lists change (a skip, shuffle, a reorder or removal on the
        // phone), as Finamp's own queue follows its queue; the phone pushes both with now playing.
        .task(id: [NowPlayingStore.shared.nowPlaying.queueEntryID] + NowPlayingStore.shared.nowPlaying.queueEntryIDs) {
            // The first load is the sheet opening; later ones follow the phone, whatever the first one did.
            let quiet = followingPhone
            followingPhone = true
            await load(quiet: quiet)
        }
    }

    // `quiet`: the phone changed the queue (a skip, an edit there), not a tap.
    private func load(quiet: Bool) async {
        do {
            state = .loaded(try await PhoneConnection.shared.queue(quiet: quiet))
        } catch {
            // A failed refresh keeps the rows already shown.
            if case .loaded = state { return }
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
    @State private var textHeight: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: QueueLayout.spacing) {
            if nowPlaying.hasTrack {
                PageTitleRow(title: nowPlaying.title, favorite: nowPlaying.favorite, heartTrack: nowPlaying.trackItem) { store.toggleFavorite() }
                    .padding(.bottom, QueueLayout.titleBottom)
                HStack(alignment: .center, spacing: PageHeader.coverToStats) {
                    CoverView(item: nowPlaying.trackItem)
                    // A square as tall as the title, artist and album next to it, so they read as one block and
                    // grow together with Text Size; capped so a three-line title can't take over the row.
                    .frame(width: coverSide, height: coverSide)
                    // One line each; long ones scroll.
                    VStack(alignment: .leading, spacing: PageHeader.statSpacing) {
                        ArtistChipsLine(artists: nowPlaying.artists, fallback: nowPlaying.artist, open: onOpenArtist)
                        if !nowPlaying.album.isEmpty {
                            Marquee {
                                Text(nowPlaying.album)
                                    .font(.caption2)
                                    .foregroundStyle(Color.fgSecondary)
                            }
                        }
                    }
                    // The cover follows a one-line version of this block (same fonts, so it grows with Text Size);
                    // measuring the real block would let a wrapping title grow the cover, which wraps the title more.
                    .background(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: PageHeader.statSpacing) {
                            if !nowPlaying.artists.isEmpty {
                                Color.clear.frame(width: 1, height: ArtistChips.height)
                            } else if !nowPlaying.artist.isEmpty {
                                Text(verbatim: "Ag").font(.footnote)
                            }
                            if !nowPlaying.album.isEmpty { Text(verbatim: "Ag").font(.caption2) }
                        }
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
                    }
                    .frame(maxWidth: .infinity)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            }
            ButtonStrip {
                LabeledIconButton(title: orderTitle, systemImage: orderIcon, tint: orderTint, titleLines: 2) {
                    await change(\.shuffled, to: !nowPlaying.shuffled, action: "togglePlaybackOrder")
                    await onOrderChange()
                }
                LabeledIconButton(title: loopTitle, systemImage: loopIcon, tint: loopTint, titleLines: 2) {
                    guard !nowPlaying.radio else { return }
                    await change(\.loop, to: Self.nextLoop[nowPlaying.loop] ?? "all", action: "toggleLoop")
                }
                .accessibilityHint(nowPlaying.radio ? Text("Not available while radio is on") : Text(""))
                LabeledIconButton(
                    title: nowPlaying.radio ? "Radio\nOn" : "Radio\nOff",
                    systemImage: nowPlaying.radio ? "radio" : "radio.off",
                    tint: nowPlaying.radioAvailable ? active : Self.inactive,
                    titleLines: 2
                ) {
                    await change(\.radio, to: !nowPlaying.radio, action: "toggleRadio")
                }
            }
            // Clear of the cover and the text above, like the album page's buttons.
            .padding(.top, PageButtons.queueStripTop)
        }
    }

    private var coverSide: CGFloat {
        let cap = rowWidth * QueueLayout.coverMaxShare
        guard textHeight > 0, rowWidth > 0 else { return max(rowWidth * QueueLayout.coverInitialShare, 1) }
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
            PhoneMessage.show(error)
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

    // Coloured by state, as Finamp's queue does: order when shuffled, loop when on (dimmed while radio is on, when it
    // can't be used), radio when it is on and can run (Finamp's availability is `disabled` while radio is off).
    private static var inactive: Color { Color.fgPrimary.opacity(0.85) }
    // The track's cover colour, as in Finamp's queue; the accent until the phone has sent it.
    private var active: Color { nowPlaying.coverColor ?? .finampBlue }
    private var loopTint: Color {
        if nowPlaying.radio { return Color.fgPrimary.opacity(0.3) }
        return nowPlaying.loop == "none" ? Self.inactive : active
    }

    private var orderTitle: LocalizedStringKey { nowPlaying.shuffled ? "Shuffled" : "In\nOrder" }
    private var orderIcon: String { nowPlaying.shuffled ? "shuffle" : "arrow.right" }
    private var orderTint: Color { nowPlaying.shuffled ? active : Self.inactive }
}

// iOS requires output selection on the phone; wait for volume before binding the crown.
struct OutputSheet: View {
    @State private var output: (route: String, routeType: String)?
    @State private var error: String?
    @State private var pickerMessage: LocalizedStringKey?
    @State private var showPickerMessage = false
    // The button's icon follows its label's text.
    @ScaledMetric(relativeTo: .footnote) private var castSize = TextSize.atLarge(.footnote) * OutputLayout.castToText

    var body: some View {
        Group {
            if let output {
                OutputControls(route: output.route, routeType: output.routeType)
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
                Label {
                    Text("Choose Output")
                } icon: {
                    FinampIcon(systemName: "airplayaudio", size: castSize)
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ThemeStore.shared.scheme?.onPrimary ?? .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OutputLayout.buttonPadding)
                    .background(Color.finampBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            // Not a list: watchOS's margin, in line with the top buttons.
            .scenePadding(.horizontal)
        }
        .alert(Text(pickerMessage ?? ""), isPresented: $showPickerMessage) {
            Button("OK", role: .cancel) {}
        }
        .task { if output == nil { await load() } }
        // The phone pushes every route change, so the sheet follows headphones connected or removed while it's open.
        .onChange(of: PhoneVolume.shared.route.map { "\($0.name)|\($0.type)" }) {
            if output != nil, let route = PhoneVolume.shared.route { output = (route.name, route.type) }
        }
    }

    private func load() async {
        error = nil
        do {
            let loaded = try await PhoneConnection.shared.output()
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

// Finamp volume multiplies with iPhone volume and has no effect during AirPlay.
@Observable
final class PhoneVolume {
    static let shared = PhoneVolume()
    // The phone's Finamp volume as last observed: its pushes, a fresh read, or its acceptance of a change.
    private(set) var value: Double?
    // The crown's newest value the phone hasn't confirmed yet (`PhoneConnection.sendVolumes`). One value for every
    // screen with the crown (Playback, the Output sheet), so a turn on one carries on from the other.
    var wanted: Double?
    var airPlay = false
    // The phone's audio route, pushed on every change.
    var route: (name: String, type: String)?
    @ObservationIgnored private var acceptedAt = Date.distantPast
    @ObservationIgnored private var recheck: Task<Void, Never>?

    // What the crown and the volume labels show: the change on its way, else the phone's volume.
    var shown: Double { wanted ?? value ?? 1 }

    // A push or context from the phone. Just after the phone accepted a change, a different pushed value may be an
    // older one still on its way, or a real change made on the phone: rather than take or drop it, ask the phone.
    func pushed(_ volume: Double) {
        let maybeOlder = Date.now.timeIntervalSince(acceptedAt) < ConnectionPolicy.Volume.olderPushWindow && abs(volume - (value ?? -1)) > 0.005
        guard maybeOlder else {
            value = volume
            return
        }
        recheck?.cancel()
        recheck = Task { await PhoneConnection.shared.recheckVolume() }
    }

    // A fresh read of the phone's volume, or (`accepted`) the phone's acceptance of a change to it.
    func observed(_ volume: Double, accepted: Bool = false) {
        value = volume
        if accepted { acceptedAt = .now }
    }

    // Shown only below 100% so a lowered volume isn't forgotten.
    var lowered: Int? {
        guard let value, value < 0.995, !airPlay else { return nil }
        return FinampFormat.percent(value)
    }
}

// The volume shown is the shared one (`PhoneVolume.shown`), the same as Playback's.
private struct OutputControls: View {
    let route: String
    let routeType: String
    private var phoneVolume: PhoneVolume { .shared }

    var body: some View {
        VStack(spacing: OutputLayout.spacing) {
            StatusIcon(asset: routeIcon, style: .title2)
            Text("Playing on")
                .font(.caption2)
                .foregroundStyle(Color.fgSecondary)
            Text(route.isEmpty ? "iPhone" : route)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            HStack(spacing: OutputLayout.volumeRowSpacing) {
                Image(systemName: "speaker.fill").font(.caption2).fixedIconSize()
                ProgressView(value: phoneVolume.airPlay ? 1 : phoneVolume.shown)
                    .tint(Color.finampBlue)
                Image(systemName: "speaker.wave.3.fill").font(.caption2).fixedIconSize()
            }
            .foregroundStyle(Color.fgSecondary)
            Group {
                if phoneVolume.airPlay {
                    Text("AirPlay sets the volume on the receiving device")
                } else {
                    Text("Finamp volume \(FinampFormat.percent(phoneVolume.shown))% · turn the crown")
                }
            }
                .font(.caption2)
                .foregroundStyle(Color.fgSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .scenePadding(.horizontal)
        .phoneVolumeCrown(showsBar: false)
    }

    // The route types are the names of `audio_session`'s `AVAudioSessionPort` the phone sends.
    private var routeIcon: String {
        switch routeType {
        case "airPlay": return "tabler-cast"
        case "bluetoothA2dp", "bluetoothLe", "bluetoothHfp": return "tabler-bluetooth"
        case "headphones": return "tabler-headphones"
        case "carAudio": return "tabler-car"
        default: return "tabler-device-mobile"
        }
    }
}

extension View {
    // The crown sets the phone's volume (`PhoneVolume`); disabled during AirPlay.
    func phoneVolumeCrown(enabled: Bool = true, showsBar: Bool = true, onTurn: @escaping () -> Void = {}) -> some View {
        modifier(PhoneVolumeCrown(enabled: enabled, showsBar: showsBar, onTurn: onTurn))
    }
}

private struct PhoneVolumeCrown: ViewModifier {
    let enabled: Bool
    let showsBar: Bool
    let onTurn: () -> Void
    // Use crown deltas; binding volume directly makes the scroll bar move downward as volume rises.
    @State private var crown = VolumeCrown.start
    // Shown only while the crown turns: with .automatic, watchOS also shows it when the screen is touched.
    @State private var turning = false
    @State private var hideBar: Task<Void, Never>?
    private var phoneVolume: PhoneVolume { .shared }

    func body(content: Content) -> some View {
        content
            .focusable(enabled && !phoneVolume.airPlay)
            .digitalCrownRotation($crown, from: VolumeCrown.range.lowerBound, through: VolumeCrown.range.upperBound, by: VolumeCrown.step, sensitivity: .low, isContinuous: true,
                                  isHapticFeedbackEnabled: true)
            .onChange(of: crown) { old, new in
                let step = new - old
                guard abs(step) < VolumeCrown.wrapGuard else { return }
                turning = true
                hideBar?.cancel()
                hideBar = Task {
                    try? await Task.sleep(for: .seconds(PlaybackLayout.volumeShownFor))
                    if !Task.isCancelled { turning = false }
                }
                // From what's shown: the change still on its way, else the phone's volume.
                let current = phoneVolume.shown
                let next = min(1, max(0, current + step))
                guard next != current else { return }
                onTurn()
                PhoneConnection.shared.setVolume(next)
            }
            .digitalCrownAccessory {
                Capsule()
                    .fill(Color.white.opacity(VolumeCrown.trackOpacity))
                    .frame(width: VolumeCrown.barWidth, height: VolumeCrown.barHeight)
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Color.finampBlue)
                            .frame(width: VolumeCrown.barWidth, height: max(VolumeCrown.barWidth, VolumeCrown.barHeight * phoneVolume.shown))
                    }
            }
            .digitalCrownAccessory(showsBar && turning ? .visible : .hidden)
    }
}

struct ProgressLine: View {
    let fraction: Double
    // Dragging or tapping the bar scrubs, releasing seeks; nil keeps it display-only.
    var dragging = false
    var onScrub: ((Double) -> Void)? = nil
    var onSeek: ((Double) -> Void)? = nil
    // The played part and the dot; the rest at 30%, as Finamp's slider (its inactive track is 35% of the same colour).
    var tint: Color = .white
    // The release reports a location up to 20 pt from the last drag point, so seek where the dot was last shown.
    @State private var lastScrub: Double?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            // Whole screen pixels: a dot drawn between pixels is smoothed differently at each position and seems to
            // pulse.
            let pixel = { (points: CGFloat) in (points * displayScale).rounded() / displayScale }
            let line = pixel(PlaybackLayout.progressLine)
            let dot = pixel(PlaybackLayout.progressDot)
            let x = pixel(geometry.size.width * min(max(fraction, 0), 1))
            let at = { (location: CGPoint) in min(max(location.x / max(geometry.size.width, 1), 0), 1) }
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(PlaybackLayout.progressRestOpacity)).frame(height: line)
                Capsule().fill(tint).frame(width: x, height: line)
                // Grows while dragging by scaling only, so the bar never shifts
                Circle().fill(tint).frame(width: dot, height: dot).scaleEffect(dragging ? PlaybackLayout.progressDotDragScale : 1)
                    .offset(x: x - dot / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // A taller touch strip below the bar, without making the layout taller.
            .padding(.bottom, PlaybackLayout.progressTouchBelow)
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
            .padding(.bottom, -PlaybackLayout.progressTouchBelow)
        }
        .frame(height: PlaybackLayout.progressHeight)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(String(localized: "\(FinampFormat.percent(fraction)) percent"))
        // VoiceOver seeks in 5% steps by swiping up or down
        .accessibilityAdjustableAction { direction in
            guard let onSeek else { return }
            switch direction {
            case .increment: onSeek(min(fraction + PlaybackLayout.progressAdjustStep, 1))
            case .decrement: onSeek(max(fraction - PlaybackLayout.progressAdjustStep, 0))
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
    // Still while dimmed, and with Reduce Motion on (Settings → Accessibility): then text that doesn't fit stays at its
    // start, cut at the edge.
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Only the content's height counts in the layout (its width would widen the page). The height comes straight
        // from the content, not from a size measured on screen: a layout that is measured but not shown (Playback's
        // `ViewThatFits`) must see the current Text Size, or it keeps the info line hidden after Text Size shrinks.
        content
            .fixedSize()
            .hidden()
            .frame(width: 0, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    content
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                    if contentSize.width > containerWidth + 1, scenePhase == .active, !reduceMotion {
                        TimelineView(.animation) { context in
                            let cycle = Double((contentSize.width + MarqueeLayout.gap) / MarqueeLayout.speed) + MarqueeLayout.pause
                            let time = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                            HStack(spacing: MarqueeLayout.gap) {
                                content
                                content
                            }
                            .fixedSize()
                            .offset(x: time < MarqueeLayout.pause ? 0 : -CGFloat(time - MarqueeLayout.pause) * MarqueeLayout.speed)
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
