import SwiftUI

// A page button: an icon over its label, in an equal share of a button strip (`PageButtons`).
struct LabeledIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    // Finamp draws these actions in the text colour; only the queue colours them, by state.
    var tint: Color = .fgPrimary
    var titleLines = 1
    let action: () async -> Void

    // Inside a `sameLabelSize()` strip: the size every label in it shares.
    @Environment(\.stripLabelScale) private var stripScale
    @Environment(\.fontResolutionContext) private var fontContext
    @State private var naturalWidth: CGFloat = 0
    @State private var width: CGFloat = 0

    // How far this label must shrink to keep `PageButtons.labelGap` to its neighbours (1 = full size).
    private var neededScale: CGFloat {
        guard stripScale != nil, naturalWidth > 0, width > 0 else { return 1 }
        return min(1, (width - PageButtons.labelGap) / naturalWidth)
    }

    private var labelFont: Font {
        guard let stripScale, stripScale < 1 else { return .caption2 }
        return .system(size: TextSize.current(.caption2, in: fontContext) * stripScale)
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: PageButtons.iconToLabel) {
                FinampIcon(systemName: systemImage, size: PageButtons.iconSize)
                    .font(.title3)
                    .fixedIconSize()
                    .foregroundStyle(tint)
                Text(title)
                    .font(labelFont)
                    .foregroundStyle(Color.fgPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(titleLines)
                    .minimumScaleFactor(PageButtons.minimumLabelScale)
                    .padding(.horizontal, PageButtons.labelGap / 2)
            }
            .frame(maxWidth: .infinity)
            .background {
                // The label's full-size width, from a hidden copy the shared size never changes (StripLabelScaleKey)
                if stripScale != nil {
                    Text(title)
                        .font(.caption2)
                        .fixedSize()
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { naturalWidth = $0 }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .preference(key: StripLabelScaleKey.self, value: neededScale)
            .padding(.vertical, PageButtons.verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// watchOS draws the top buttons; only the icon is Finamp's.
struct UpperIcon: View {
    let systemName: String

    var body: some View {
        FinampIcon(systemName: systemName, size: 20)
    }
}

extension View {
    // watchOS draws these icons white, so tint with the light scheme's primary, which Material pairs with white.
    func upperButtonStyle() -> some View {
        tint(ThemeStore.shared.switchTint)
    }
}

struct RetryView: View {
    let message: String
    // In a List: the list scrolls and gives the margins.
    var inList = false
    let retry: () async -> Void

    var body: some View {
        if inList {
            content
        } else {
            // On a short screen the page doesn't fit under the title: it scrolls rather than cutting its text, and is
            // centred when it fits. The text sits on watchOS's margin, in line with the top buttons.
            GeometryReader { proxy in
                ScrollView {
                    content
                        .scenePadding(.horizontal)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            Image(systemName: isServer ? "wifi.slash" : "iphone.slash")
                .font(.title2)
                .fixedIconSize()
                .foregroundStyle(.finampGradient)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(Color.fgSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Retry") { Task { await retry() } }
                .tint(.finampBlue)
        }
    }

    private var isServer: Bool { message == PhoneError.serverUnreachable.localizedDescription }

    private var hint: LocalizedStringKey? {
        if isServer { return "Turn on Offline Mode in Settings to play your downloads" }
        let phoneUnavailable = [PhoneError.notReachable.localizedDescription, PhoneError.noAnswer.localizedDescription, "Finamp is still starting"]
        return phoneUnavailable.contains(message) ? "Open Finamp on your iPhone" : nil
    }
}

// A page's title row, under the top buttons and above the cover: the name in up to two lines, then its heart and
// any trailing button (the download), centred on the title however many lines it takes. Used by the artist, album,
// playlist and queue pages.
struct PageTitleRow<Trailing: View>: View {
    let title: String
    // nil hides the heart.
    var favorite: Bool?
    var onFavorite: () -> Void = {}
    @ViewBuilder var trailing: Trailing
    // Follows the title's text.
    @ScaledMetric(relativeTo: .headline) private var heartSize = PageHeader.heartSize

    var body: some View {
        // A small gap after the title so it keeps as many letters as it can; the buttons keep theirs.
        HStack(alignment: .center, spacing: PageHeader.titleToButtons) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.fgPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: PageHeader.buttonSpacing) {
                if let favorite {
                    Button(action: onFavorite) {
                        FavoriteHeart(filled: favorite, size: heartSize)
                            .foregroundStyle(Color.fgPrimary)
                            .iconTapArea(heartSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
                }
                trailing
            }
        }
    }
}

extension PageTitleRow where Trailing == EmptyView {
    init(title: String, favorite: Bool? = nil, onFavorite: @escaping () -> Void = {}) {
        self.init(title: title, favorite: favorite, onFavorite: onFavorite) { EmptyView() }
    }
}

// One line of a page's stats, as Finamp's IconAndText: the icon at half opacity stays put, and only the text, on one
// line, scrolls when it doesn't fit.
struct StatLine: View {
    let symbol: String
    let text: String
    // Follows the stat's text.
    @ScaledMetric(relativeTo: .caption2) private var iconSize = PageHeader.statIconSize

    var body: some View {
        HStack(spacing: PageHeader.statIconToText) {
            FinampIcon(systemName: symbol, size: iconSize)
                .foregroundStyle(Color.fgPrimary.opacity(0.5))
            Marquee {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(Color.fgPrimary)
            }
        }
    }
}

// A cover and its text sharing the row in halves, as on the album and artist pages. Used where the page's name is the
// navigation title instead of a title row.
struct HalvesCoverRow<Cover: View, Info: View>: View {
    @ViewBuilder let cover: Cover
    @ViewBuilder let info: Info

    var body: some View {
        HStack(alignment: .center, spacing: PageHeader.coverToStats) {
            cover.frame(maxWidth: .infinity)
            // Holds its half even when there is no text yet.
            ZStack(alignment: .leading) {
                Color.clear.frame(height: 1)
                info
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Finamp's wording and number formats for the stats (trackCount, albumCount, printDuration).
enum FinampFormat {
    static func tracks(_ n: Int) -> String { n == 1 ? String(localized: "1 Track") : String(localized: "\(n) Tracks") }
    static func albums(_ n: Int) -> String { n == 1 ? String(localized: "1 Album") : String(localized: "\(n) Albums") }

    // Two-digit fields with leading zeros: 05:20, 01:02:03.
    static func duration(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

// Finamp's favourite heart (Material's favorite / favorite_border), not the SF Symbol.
struct FavoriteHeart: View {
    let filled: Bool
    let size: CGFloat

    var body: some View {
        Image(filled ? "material-favorite" : "material-favorite-border")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// Tabler icons used where they differ from SF Symbols.
struct FinampIcon: View {
    let systemName: String
    let size: CGFloat

    private static let tabler = [
        "shuffle": "tabler-arrows-shuffle",
        "heart.circle": "tabler-heart-question",
        "clock.arrow.circlepath": "tabler-restore",
        "sparkles": "tabler-radio",
        "repeat": "tabler-repeat",
        "repeat.1": "tabler-repeat-once",
        "repeat.off": "tabler-repeat-off",
        "arrow.right": "tabler-arrows-right",
        "radio": "tabler-radio",
        "radio.off": "tabler-radio-off",
        "list.bullet": "tabler-playlist",
        "hifispeaker": "tabler-device-speaker",
        "magnifyingglass": "tabler-search",
        "arrow.down.circle": "tabler-download",
        "arrow.down.circle.fill": "tabler-device-sd-card",
        "lock.circle": "tabler-lock",
        "trash": "tabler-trash",
        // The artist page's counts, as on Finamp's artist screen
        "music.note": "material-music-note",
        "opticaldisc": "tabler-disc",
        "calendar": "material-event",
        // Finamp's Material heart, as on Playback and the track rows
        "heart": "material-favorite-border",
        "heart.fill": "material-favorite",
    ]

    var body: some View {
        if let asset = Self.tabler[systemName] {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemName)
        }
    }
}
