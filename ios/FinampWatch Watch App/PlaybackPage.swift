import SwiftUI
import WatchKit

/// Phone playback state; position is in seconds at updatedAt and advances locally while playing.
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
    /// Playback mode, codec and bitrate; empty until the phone has metadata.
    var audio = ""
    var duration: Double = 0
    var position: Double = 0
    var updatedAt = Date()
    var playing = false
    var favorite = false

    func position(at date: Date) -> Double {
        let elapsed = playing ? date.timeIntervalSince(updatedAt) : 0
        return min(max(position + elapsed, 0), duration)
    }
}

@Observable
final class NowPlayingStore {
    static let shared = NowPlayingStore()

    var nowPlaying = NowPlaying()
    /// When the phone last sent now playing, pushed or asked for.
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
            audio: state["audio"] as? String ?? "",
            duration: state["duration"] as? Double ?? 0,
            position: state["position"] as? Double ?? 0,
            updatedAt: Date(timeIntervalSince1970: state["updatedAt"] as? Double ?? Date().timeIntervalSince1970),
            playing: state["playing"] as? Bool ?? false,
            favorite: state["favorite"] as? Bool ?? false
        )
        if nowPlaying.hasTrack, let favorite = state["favorite"] as? Bool {
            FavoriteOverrides.shared.phoneReported(nowPlaying.id, favorite)
        }
    }
}

/// Playback controls for the phone's current track.
struct PlaybackPage: View {
    let isActive: Bool

    @State private var store = NowPlayingStore.shared
    @State private var artwork: UIImage?
    /// The key `artwork` belongs to; until the new track's cover arrives its BlurHash is shown instead.
    @State private var artworkFor = ""
    @State private var showSystemPlayer = false
    @State private var showQueue = false
    /// The crown sets Finamp's volume here too; the audio line shows it while the crown turns.
    @State private var crownVolume = PhoneVolume.shared.value ?? 1
    @State private var showVolume = false
    @State private var hideVolume: Task<Void, Never>?

    private var nowPlaying: NowPlaying { store.nowPlaying }

    private var cornerIconColor: Color { artwork == nil ? Color.fgPrimary : .white }

    /// Full-screen pixel size rounded to the same cache buckets as other covers.
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
            QueueView()
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
                    Image(systemName: "iphone")
                        .foregroundStyle(cornerIconColor)
                }
                .accessibilityLabel("Output and Volume")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(cornerIconColor)
                }
                .accessibilityLabel("Queue")
                .disabled(!nowPlaying.hasTrack)
            }
        }
        .task(id: nowPlaying.artworkKey) {
            guard !nowPlaying.artworkKey.isEmpty else {
                artwork = nil
                return
            }
            let item = LibraryItem(
                id: nowPlaying.id,
                name: nowPlaying.title,
                subtitle: "",
                artworkKey: nowPlaying.artworkKey,
                artworkURL: nowPlaying.artworkURL
            )
            let loaded = await ArtworkStore.shared.image(for: item, size: artworkPixels)
            withAnimation(.easeIn(duration: 0.7)) {
                artwork = loaded
                artworkFor = nowPlaying.artworkKey
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
        if let artwork = current ?? BlurHash.image(nowPlaying.blurHash) ?? artwork {
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

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Marquee {
                        Text(nowPlaying.title)
                            .font(.system(size: UIFont.preferredFont(forTextStyle: .title3).pointSize * 0.9))
                            .lineLimit(1)
                    }
                    artistLine
                }
                Spacer(minLength: 0)
                Button {
                    // Capture this track's id before sending; the phone's favourite state is authoritative.
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
                    Image(systemName: nowPlaying.favorite ? "heart.fill" : "heart")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background {
                            if nowPlaying.favorite {
                                Circle().fill(.finampGradient)
                            } else {
                                Circle().fill(.white.opacity(0.18))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nowPlaying.favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
            }

            VStack(alignment: .leading, spacing: 3) {
                if showVolume {
                    Label("Finamp volume \(Int((crownVolume * 100).rounded()))%", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                } else if !nowPlaying.audio.isEmpty {
                    Text(nowPlaying.audio)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                if !showVolume, let lowered = PhoneVolume.shared.lowered {
                    Label("Finamp volume \(lowered)%", systemImage: "speaker.wave.1.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let position = nowPlaying.position(at: context.date)
                    HStack(spacing: 6) {
                        Text(formatDuration(position))
                            .foregroundStyle(.white.opacity(0.75))
                        ProgressLine(fraction: nowPlaying.duration > 0 ? position / nowPlaying.duration : 0)
                        Text("-" + formatDuration(nowPlaying.duration - position))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .font(.system(size: 10).monospacedDigit())
                }
            }
            .padding(.bottom, -3)

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
        .padding(.horizontal, 6)
        // Text stays light over the darkened cover in either theme.
        .foregroundStyle(.white)
        .padding(.bottom, Self.bottomGap)
        .ignoresSafeArea(edges: .bottom)
    }

    private static let playSize: CGFloat = 48

    /// Model-specific page-dot heights require different gaps below the Play button.
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
            Task { try? await PhoneConnection.shared.control(action) }
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

    /// Artist links, falling back to names until the phone supplies artist details.
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
                            ArtistLabel(artist: artist, color: .white.opacity(0.9))
                            .padding(.leading, 2)
                            .padding(.trailing, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Artist \(artist.name)")
                    }
                }
            }
        }
    }

}

/// Upcoming tracks, with tap-to-skip.
struct QueueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state: ListState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ScrollView { SkeletonTrackRows(count: 5) }
            case .failed(let message):
                RetryView(message: message) { await load() }
            case .loaded(let tracks):
                if tracks.isEmpty {
                    Text("Nothing up next")
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                } else {
                    List(Array(tracks.enumerated()), id: \.offset) { index, track in
                        TrackRow(track: track, onTap: {
                            Task {
                                try? await PhoneConnection.shared.skipTo(id: track.id)
                                dismiss()
                            }
                        })
                        // Override the system's nearly white row background in the light theme.
                        .listRowBackground(TrackRowBackground(isPlaying: false))
                    }
                }
            }
        }
        .navigationTitle("Up Next")
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

/// Phone output and crown volume controls; iOS requires output selection on the phone.
/// Wait for the phone's volume before binding the crown to avoid a placeholder jump.
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
                    .foregroundStyle(.white)
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

/// Tighter spacing for 40 mm and 41 mm watches.
private let isSmallWatch = WKInterfaceDevice.current().screenBounds.height < 220

/// Output controls initialized with the phone's volume before the crown is bound.
/// Finamp's own volume as the phone last pushed it (it multiplies with the iPhone's volume), and whether AirPlay
/// plays, when Finamp's volume has no effect and Finamp disables it.
@Observable
final class PhoneVolume {
    static let shared = PhoneVolume()
    var value: Double?
    var airPlay = false

    /// Finamp's volume when below 100% and it matters, so a lowered volume isn't forgotten.
    var lowered: Int? {
        guard let value, value < 0.995, !airPlay else { return nil }
        return Int((value * 100).rounded())
    }
}

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
                .foregroundStyle(.finampGradient)
            Text("Playing on")
                .font(.caption2)
                .foregroundStyle(Color.fgSecondary)
            Text(route.isEmpty ? "iPhone" : route)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.caption2)
                ProgressView(value: phoneVolume.airPlay ? 1 : volume)
                    .tint(Color.finampBlue)
                Image(systemName: "speaker.wave.3.fill").font(.caption2)
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
    /// Binds the Digital Crown to Finamp's volume on the phone; off during AirPlay, as Finamp disables its slider.
    /// `showsBar` adds a volume bar beside the crown, for screens without their own.
    func phoneVolumeCrown(
        _ volume: Binding<Double>, enabled: Bool = true, showsBar: Bool = true, onTurn: @escaping () -> Void = {}
    ) -> some View {
        modifier(PhoneVolumeCrown(volume: volume, enabled: enabled, showsBar: showsBar, onTurn: onTurn))
    }
}

/// Sends crown turns as Finamp's volume (one message in flight) and follows the phone's own changes, except just after
/// the crown moved, since the phone echoes those.
private struct PhoneVolumeCrown: ViewModifier {
    @Binding var volume: Double
    let enabled: Bool
    let showsBar: Bool
    let onTurn: () -> Void
    @State private var lastCrownChange = Date.distantPast
    @State private var applyingPhoneVolume = false
    /// A continuous crown position; only its changes matter. A bounded binding makes watchOS draw a scroll bar that
    /// moves down as the value rises.
    @State private var crown = 500.0
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
                let next = min(1, max(0, volume + step))
                if next != volume { volume = next }
            }
            // Beside the crown, a bar that fills upward with the volume
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
            .digitalCrownAccessory(showsBar ? .automatic : .hidden)
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

/// A playback progress line with a position dot.
struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            let x = geometry.size.width * min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3)).frame(height: 3)
                Capsule().fill(.white).frame(width: x, height: 3)
                Circle().fill(.white).frame(width: 9, height: 9).offset(x: x - 4.5)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(String(localized: "\(Int((min(max(fraction, 0), 1) * 100).rounded())) percent"))
    }
}

/// Scrolls overflowing content in a loop, pausing at the start.
struct Marquee<Content: View>: View {
    @ViewBuilder let content: Content

    @State private var contentSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0

    private let gap: CGFloat = 24
    /// Points per second.
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
                    if contentSize.width > containerWidth + 1 {
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
                    }
                }
            }
            .clipped()
    }
}
