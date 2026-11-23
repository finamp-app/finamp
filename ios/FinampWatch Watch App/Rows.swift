import SwiftUI

// A cover and its title and subtitle (`CoverRows`), as tall as the cover (`CoverRowLayout`). `subtitle` replaces the
// item's own (a playlist's track count).
struct CoverRow: View {
    let item: LibraryItem
    let coverShare: CGFloat
    var circular = false
    var subtitle: String? = nil

    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        CoverRowLayout(spacing: CoverRows.coverToText) {
            CoverView(item: item, circular: circular)
                .containerRelativeFrame(.horizontal) { width, _ in width * coverShare }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(.system(size: TextSize.current(.title3, in: fontContext) * CoverRows.titleScale))
                    .lineLimit(2)
                if let line = subtitle ?? (item.subtitle.isEmpty ? nil : item.subtitle) {
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .lineLimit(1)
                        // The subtitle keeps its line; the title gives up its second line first.
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

struct CollectionLink: View {
    let item: LibraryItem
    let kind: LibraryKind

    var body: some View {
        NavigationLink(value: kind == .artists ? .artistAlbums(item) : LibraryDestination.tracks(item, type: kind.type)) {
            CoverRow(
                item: item,
                coverShare: kind.coverShare,
                circular: kind == .artists,
                // A playlist's track count under its name, as in its page and the playlist menu.
                subtitle: kind == .playlists ? FinampFormat.tracks(item.trackCount) : nil
            )
        }
        .buttonStyle(.plain)
    }
}

// Finamp's artist chip: a rounded rectangle with the artist's image, if it has one, square on the left. The defaults
// are Finamp's own (theme text on 10% white); Playback passes the colours it draws over the cover.
struct ArtistChip: View {
    let artist: LibraryItem
    var textColor = Color.fgPrimary
    var background = Color.white.opacity(0.1)
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = ArtistChip.height
    static let height: CGFloat = 20
    @Environment(\.displayScale) private var displayScale
    // The phone sends a URL for every artist, so a missing image is only known once loading fails.
    @State private var image: UIImage?

    var body: some View {
        HStack(spacing: 0) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: height, height: height)
                    .clipped()
            }
            Text(artist.name)
                .font(.footnote)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 5)
        }
        .frame(height: height)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: ArtistChips.cornerRadius))
        .task(id: artist.artworkKey) {
            guard !artist.artworkKey.isEmpty else { return image = nil }
            let loaded = await ArtworkStore.shared.image(for: artist, size: Int((height * displayScale / 20).rounded(.up)) * 20)
            // A slower load for an earlier artist must not replace the current one's photo
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

// A track: title, artist and duration, the playing bars while it plays, and its heart (`TrackRows`).
struct TrackRow: View {
    let track: LibraryItem
    var onFavorite: (() -> Void)? = nil
    var favorite = false
    var onTap: (() -> Void)? = nil
    var enlarged = false

    @State private var store = NowPlayingStore.shared
    @Environment(\.fontResolutionContext) private var fontContext

    // Relative sizes, since watchOS text styles below footnote differ by only a few points.
    private var footnoteSize: CGFloat { TextSize.current(.footnote, in: fontContext) }

    private var scale: CGFloat { enlarged ? TrackRows.enlargedTextScale : 1 }

    private var heartSize: CGFloat {
        footnoteSize * (enlarged ? TrackRows.enlargedHeartScale : 1) * TrackRows.heartScale
    }

    private var isPlaying: Bool { store.nowPlaying.hasTrack && store.nowPlaying.id == track.id }

    private var showsBars: Bool { isPlaying && store.nowPlaying.playing }
    // The bars sit centred in the room left of the title, on whatever inset the row has (measured, TrackRowMargin).
    private var barsInset: CGFloat { TrackRowMargin.shared.value - TrackRows.barsGap }
    // Against the title's size, so they follow Text Size.
    private var barsHeight: CGFloat { footnoteSize * scale * TrackRows.barsHeightScale }

    // Set by `cardRow()` in a card list: the row then draws its own card.
    @Environment(\.trackCardFrame) private var card
    // The title block's height without the card's padding, for the card padding (TrackCardContentHeightKey).
    @State private var contentHeight: CGFloat = 0

    // Title, artist and duration, and the playing bars.
    private var text: some View {
        VStack(alignment: .leading, spacing: TrackRows.titleToSubtitle) {
            Text(track.name)
                .font(.system(size: footnoteSize * scale, weight: TrackRows.titleWeight))
                .foregroundStyle(isPlaying ? Color.finampBlue : Color.fgPrimary)
                .lineLimit(1)
            HStack(spacing: TrackRows.artistToDuration) {
                Text(track.subtitle)
                    .lineLimit(1)
                Spacer(minLength: TrackRows.artistToDuration)
                if track.duration > 0 {
                    // Never wraps or shortens; the artist is cut instead
                    Text(formatDuration(track.duration))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .font(.system(size: footnoteSize * TrackRows.subtitleScale * scale))
            .foregroundStyle(Color.fgSecondary)
        }
        // Finamp's playing indicator while the track plays: the bars reach a little into the row's margin, and the
        // title and artist move right to make room, on this row only.
        .padding(.leading, showsBars ? PlayingBars.width(barsHeight) - barsInset + TrackRows.barsGap : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            if showsBars {
                PlayingBars(color: Color.finampBlue, height: barsHeight)
                    .offset(x: -barsInset)
            }
        }
    }

    private var heartGlyph: some View {
        FavoriteHeart(filled: favorite, size: heartSize)
            .foregroundStyle(favorite ? Color.fgPrimary : Color.fgSecondary)
    }

    private var heartLabel: String {
        favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite")
    }

    var body: some View {
        Group {
            if let card {
                cardBody(card)
            } else {
                plainBody
            }
        }
        .preference(key: TrackCardContentHeightKey.self, value: contentHeight)
    }

    // In a card list: the whole card is one button, so pressing it darkens and shrinks the card as Home's cards do.
    // The heart's glyph is part of the card; its tap area is a separate button on top, so it never presses the row.
    private func cardBody(_ card: TrackCardFrame) -> some View {
        Button { onTap?() } label: {
            HStack(spacing: TrackRows.textToHeart) {
                text
                if onFavorite != nil { heartGlyph.accessibilityHidden(true) }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            // The playing row's content width, for TrackRowMargin.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { if isPlaying { TrackRowMargin.shared.contentWidth = $0 } }
            .padding(.leading, card.leading)
            .padding(.trailing, card.trailing)
            .padding(.vertical, card.vertical)
            .background(TrackRowBackground(isPlaying: card.isPlaying))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if let onFavorite {
                Color.clear
                    .frame(width: IconButtons.tapSize)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .trackHeart(track, like: onFavorite)
                // Centred on the glyph: the tap area reaches past it on both sides.
                .padding(.trailing, card.trailing - (IconButtons.tapSize - heartSize) / 2)
                .accessibilityLabel(heartLabel)
            }
        }
    }

    // Outside a card list (until the card's measurements arrive): the text is the button, the heart its own.
    private var plainBody: some View {
        HStack(spacing: TrackRows.textToHeart) {
            Button { onTap?() } label: {
                text.contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onFavorite {
                // The layout gives the heart only its glyph's size, so the row keeps its height and the labels their
                // room; the tap area reaches past the glyph on every side.
                heartGlyph
                    .iconTapArea(heartSize)
                    .trackHeart(track, like: onFavorite)
                    .accessibilityLabel(heartLabel)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        // The playing row's content width, for TrackRowMargin.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { if isPlaying { TrackRowMargin.shared.contentWidth = $0 } }
    }
}

// Finamp's playing indicator (its mini_music_visualizer): three bottom-aligned bars, 4 × 15 with radius 2 in Finamp
// (scaled to the row's text here), each bouncing between 2 and full height with the bounce-out curve, back and forth,
// over 0.9, 0.8 and 0.7 s. Still while the watch is dimmed, and with Reduce Motion on, as the scrolling text.
struct PlayingBars: View {
    let color: Color
    let height: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let durations: [Double] = [0.9, 0.8, 0.7]

    // The three bars and the two gaps between them
    static func width(_ height: CGFloat) -> CGFloat { height * 4 / 15 * 4 }

    var body: some View {
        let barWidth = height * 4 / 15
        TimelineView(.animation(paused: scenePhase != .active || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: barWidth / 2) {
                ForEach(0..<3, id: \.self) { index in
                    let duration = Self.durations[index]
                    let phase = time.truncatingRemainder(dividingBy: 2 * duration) / duration
                    let barHeight = 2 + (height - 2) * Self.bounceOut(phase <= 1 ? phase : 2 - phase)
                    RoundedRectangle(cornerRadius: min(barWidth / 2, barHeight / 2))
                        .fill(color)
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(height: height, alignment: .bottom)
        }
        .accessibilityLabel("Playing")
    }

    // Flutter's Curves.bounceOut
    private static func bounceOut(_ x: Double) -> Double {
        var t = x
        if t < 1 / 2.75 { return 7.5625 * t * t }
        if t < 2 / 2.75 { t -= 1.5 / 2.75; return 7.5625 * t * t + 0.75 }
        if t < 2.5 / 2.75 { t -= 2.25 / 2.75; return 7.5625 * t * t + 0.9375 }
        t -= 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    }
}

// A track card's fill; the playing track's in the accent.
struct TrackRowBackground: View {
    let isPlaying: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Cards.trackCornerRadius)
            .fill(isPlaying ? Color.finampBlue.opacity(0.22) : Color.listFill)
            // The playing row's full width, for TrackRowMargin.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { if isPlaying { TrackRowMargin.shared.rowWidth = $0 } }
    }
}

// The inset between a track row's edge and its content, (row width − content width) / 2, measured on the playing row
// so the playing bars stay centred whatever the row's inset is. Layout widths, not screen positions, so it holds still
// while watchOS shrinks rows at the screen's edges.
@Observable
final class TrackRowMargin {
    static let shared = TrackRowMargin()
    var rowWidth: CGFloat = 0
    var contentWidth: CGFloat = 0

    // `TrackRows.barsFallbackInset` until both are measured, or if the numbers make no sense.
    var value: CGFloat {
        let margin = (rowWidth - contentWidth) / 2
        return rowWidth > 0 && contentWidth > 0 && (2...30).contains(margin) ? margin : TrackRows.barsFallbackInset
    }
}

func formatDuration(_ seconds: Double) -> String {
    let total = max(Int(seconds.rounded()), 0)
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let secs = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
}
