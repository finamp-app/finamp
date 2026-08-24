import AppIntents
import SwiftUI
import WidgetKit

struct FinampNowPlayingEntry: TimelineEntry {
    let date: Date
    let state: FinampWidgetState
}

struct FinampNowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinampNowPlayingEntry {
        .init(date: .now, state: .empty)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FinampNowPlayingEntry) -> Void
    ) {
        completion(.init(date: .now, state: .load()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FinampNowPlayingEntry>) -> Void
    ) {
        let entry = FinampNowPlayingEntry(date: .now, state: .load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct FinampNowPlayingWidget: Widget {
    let kind = FinampWidgetShared.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinampNowPlayingProvider()) { entry in
            FinampWidgetRootView(state: entry.state)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Finamp Now Playing")
        .description("Control playback and rate the current track.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct FinampWidgetRootView: View {
    @Environment(\.widgetFamily) private var family
    let state: FinampWidgetState

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(state: state)
        case .systemMedium:
            MediumWidgetView(state: state)
        case .systemLarge:
            LargeWidgetView(state: state)
        default:
            MediumWidgetView(state: state)
        }
    }
}

private struct CoverView: View {
    let state: FinampWidgetState

    var body: some View {
        Group {
            if let image = loadCoverImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }

    private func loadCoverImage() -> UIImage? {
        guard
            let container = FinampWidgetShared.containerURL,
            let itemID = state.itemID
        else {
            return nil
        }

        let url = container
            .appendingPathComponent("\(FinampWidgetShared.coverFileName)-\(itemID)")
            .appendingPathExtension("jpg")

        return UIImage(contentsOfFile: url.path)
    }
}

private struct TrackText: View {
    let state: FinampWidgetState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(state.title)
                .font(compact ? .caption.bold() : .headline)
                .lineLimit(1)
            if !state.artist.isEmpty {
                Text(state.artist)
                    .font(compact ? .caption2 : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !compact && !state.album.isEmpty {
                Text(state.album)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}

private struct PlaybackButton: View {
    let state: FinampWidgetState

    var body: some View {
        Button(intent: TogglePlaybackIntent()) {
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(.headline)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.isPlaying ? "Pause" : "Play")
    }
}

private struct TransportControls: View {
    let state: FinampWidgetState

    var body: some View {
        HStack(spacing: 20) {
            Button(intent: PreviousTrackIntent()) {
                Image(systemName: "backward.fill")
            }
            .accessibilityLabel("Previous track")

            PlaybackButton(state: state)

            Button(intent: NextTrackIntent()) {
                Image(systemName: "forward.fill")
            }
            .accessibilityLabel("Next track")
        }
        .buttonStyle(.plain)
        .font(.headline)
    }
}

private struct RatingOrFavoriteView: View {
    let state: FinampWidgetState
    let compact: Bool

    var body: some View {
        if #available(iOS 27.0, *) {
            if state.showStarRatings {
                StarRatingView(state: state, compact: compact)
            } else {
                Button(intent: ToggleFavoriteIntent()) {
                    Image(systemName: state.isFavorite ? "heart.fill" : "heart")
                        .font(compact ? .body : .title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(state.isFavorite ? "Remove favorite" : "Add favorite")
            }
        } else {
            if state.showStarRatings {
                StarDisplayView(rating: state.starRating, compact: compact)
            } else {
                Image(systemName: state.isFavorite ? "heart.fill" : "heart")
                    .font(compact ? .body : .title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(iOS 27.0, *)
private struct StarRatingView: View {
    let state: FinampWidgetState
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 2 : 5) {
            ForEach(1...5, id: \.self) { star in
                let selected = (state.starRating ?? 0) >= Double(star)
                let clears = state.starRating == Double(star)

                if clears {
                    Button(intent: ClearStarRatingIntent()) {
                        starImage(selected: selected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear rating")
                } else {
                    Button(intent: SetStarRatingIntent(stars: Double(star))) {
                        starImage(selected: selected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) of 5 stars")
                }
            }
        }
    }

    @ViewBuilder
    private func starImage(selected: Bool) -> some View {
        Image(systemName: selected ? "star.fill" : "star")
            .font(compact ? .caption : .body)
    }
}

private struct StarDisplayView: View {
    let rating: Double?
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 2 : 5) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: (rating ?? 0) >= Double(star) ? "star.fill" : "star")
                    .font(compact ? .caption : .body)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private struct SmallWidgetView: View {
    let state: FinampWidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                CoverView(state: state)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                SmallRatingOrFavoriteView(state: state)
                    .frame(width: 24, alignment: .center)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(state.title)
                    .font(.caption.bold())
                    .lineLimit(1)

                if !state.artist.isEmpty {
                    Text(state.artist)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Previous track")

                Spacer(minLength: 2)

                PlaybackButton(state: state)

                Spacer(minLength: 2)

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Next track")
            }
            .buttonStyle(.plain)
            .font(.body)
        }
    }
}

private struct SmallRatingOrFavoriteView: View {
    let state: FinampWidgetState

    var body: some View {
        if #available(iOS 27.0, *) {
            if state.showStarRatings {
                let hasRating = state.starRating != nil

                if hasRating {
                    Button(intent: ClearStarRatingIntent()) {
                        Image(systemName: "star.fill")
                    }
                    .accessibilityLabel("Clear rating")
                } else {
                    Button(intent: SetStarRatingIntent(stars: 5)) {
                        Image(systemName: "star")
                    }
                    .accessibilityLabel("Rate 5 stars")
                }
            } else {
                Button(intent: ToggleFavoriteIntent()) {
                    Image(
                        systemName: state.isFavorite
                            ? "heart.fill"
                            : "heart"
                    )
                }
                .accessibilityLabel(
                    state.isFavorite
                        ? "Remove favorite"
                        : "Add favorite"
                )
            }
        } else {
            if state.showStarRatings {
                Image(
                    systemName: state.starRating == nil
                        ? "star"
                        : "star.fill"
                )
                .foregroundStyle(.secondary)
            } else {
                Image(
                    systemName: state.isFavorite
                        ? "heart.fill"
                        : "heart"
                )
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MediumWidgetView: View {
    let state: FinampWidgetState

    var body: some View {
        HStack(spacing: 12) {
            CoverView(state: state)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                TrackText(state: state, compact: false)
                Spacer(minLength: 0)
                TransportControls(state: state)
                RatingOrFavoriteView(state: state, compact: false)
            }
        }
    }
}

private struct LargeWidgetView: View {
    let state: FinampWidgetState

    var body: some View {
        VStack(spacing: 8) {
            CoverView(state: state)
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 2) {
                Text(state.title)
                    .font(.title3.bold())
                    .lineLimit(1)

                if !state.artist.isEmpty {
                    Text(state.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !state.album.isEmpty {
                    Text(state.album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                RatingOrFavoriteView(
                    state: state,
                    compact: false
                )
                .padding(.top, 3)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Previous track")

                Spacer()

                PlaybackButton(state: state)

                Spacer()

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Next track")
            }
            .buttonStyle(.plain)
            .font(.title3)
        }
    }
}
