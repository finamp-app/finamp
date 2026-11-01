import SwiftUI

/// A library cover, title and optional subtitle.
struct CoverRow: View {
    let item: LibraryItem
    let placeholderSymbol: String
    let coverFraction: CGFloat
    var circular = false

    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        HStack(spacing: 10) {
            CoverView(item: item, placeholderSymbol: placeholderSymbol, circular: circular)
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

/// A cover row that opens an artist's albums or a collection's tracks.
struct CollectionLink: View {
    let item: LibraryItem
    let kind: LibraryKind

    var body: some View {
        NavigationLink(value: kind == .artists ? .artistAlbums(item) : LibraryDestination.tracks(item, type: kind.type)) {
            CoverRow(
                item: item,
                placeholderSymbol: kind.placeholderSymbol,
                coverFraction: kind.coverFraction,
                circular: kind == .artists
            )
        }
        .buttonStyle(.plain)
    }
}

/// An artist's round photo and name, as shown in artist links.
struct ArtistLabel: View {
    let artist: LibraryItem
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            CoverView(item: artist, placeholderSymbol: LibraryKind.artists.placeholderSymbol, circular: true)
                .frame(width: 16, height: 16)
            Text(artist.name)
                .font(.footnote)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// A track row with an optional favourite action.
struct TrackRow: View {
    let track: LibraryItem
    /// When set, shows a heart that invokes this action.
    var onFavorite: (() -> Void)? = nil
    var favorite = false
    var onTap: (() -> Void)? = nil
    /// Enlarges text and the heart for full track lists.
    var enlarged = false

    @State private var store = NowPlayingStore.shared
    @Environment(\.fontResolutionContext) private var fontContext

    /// Use relative sizes because watchOS text styles below footnote differ by only a few points.
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
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .font(.system(size: TextSize.atLarge(.footnote) * (enlarged ? 2 : 1), weight: .semibold))
                        .foregroundStyle(favorite ? Color.finampPurple : Color.fgSecondary)
                        .frame(width: enlarged ? 36 : 22, height: enlarged ? nil : 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
            }
        }
    }
}

/// A themed row background that highlights the playing track.
struct TrackRowBackground: View {
    let isPlaying: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isPlaying ? Color.finampBlue.opacity(0.22) : Color.listFill)
    }
}

/// Formats seconds as "3:07" or "1:02:45".
func formatDuration(_ seconds: Double) -> String {
    let total = max(Int(seconds.rounded()), 0)
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let secs = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
}
