import SwiftUI

struct CoverRow: View {
    let item: LibraryItem
    let coverFraction: CGFloat
    var circular = false

    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        HStack(spacing: 10) {
            CoverView(item: item, circular: circular)
                .containerRelativeFrame(.horizontal) { width, _ in width * coverFraction }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(.system(size: TextSize.current(.title3, in: fontContext) * 0.88))
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.fgSecondary)
                        .lineLimit(1)
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
                coverFraction: kind.coverFraction,
                circular: kind == .artists
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
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task(id: artist.artworkKey) {
            guard !artist.artworkKey.isEmpty else { return image = nil }
            image = await ArtworkStore.shared.image(for: artist, size: Int((height * displayScale / 20).rounded(.up)) * 20)
        }
    }
}

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

    private var scale: CGFloat { enlarged ? 1.13 : 1 }

    private var isPlaying: Bool { store.nowPlaying.hasTrack && store.nowPlaying.id == track.id }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.name)
                        .font(.system(size: footnoteSize * scale, weight: .medium))
                        .foregroundStyle(isPlaying ? Color.finampBlue : Color.fgPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(track.subtitle)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if track.duration > 0 {
                            Text(formatDuration(track.duration))
                                .monospacedDigit()
                        }
                    }
                    .font(.system(size: footnoteSize * 0.75 * scale))
                    .foregroundStyle(Color.fgSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            if let onFavorite {
                Button(action: onFavorite) {
                    // The glyph fills about 85% of its box, so 1.2× matches the old symbol at this font size.
                    FavoriteHeart(filled: favorite, size: TextSize.atLarge(.footnote) * (enlarged ? 2 : 1) * 1.2)
                        .foregroundStyle(favorite ? Color.fgPrimary : Color.fgSecondary)
                        .frame(width: enlarged ? 36 : 22, height: enlarged ? nil : 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
            }
        }
    }
}

struct TrackRowBackground: View {
    let isPlaying: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isPlaying ? Color.finampBlue.opacity(0.22) : Color.listFill)
    }
}

func formatDuration(_ seconds: Double) -> String {
    let total = max(Int(seconds.rounded()), 0)
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let secs = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
}
