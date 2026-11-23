import SwiftUI

// A page button in a `ButtonStrip`: an icon over its label, centred in its part of the strip; the whole part is its
// tap area. The strip decides the label's size (`ButtonStrip`); the button only reports its full-size label width.
struct LabeledIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    // Finamp draws these actions in the text colour; only the queue colours them, by state.
    var tint: Color = .fgPrimary
    var titleLines = 1
    let action: () async -> Void

    @Environment(\.stripLabelScale) private var stripScale
    // The small text on Apple's curve at the current Text Size; the label size follows it (`PageButtons.labelSize`).
    @ScaledMetric(relativeTo: .caption2) private var appleScaled = SmallText.atLarge
    private var labelSize: CGFloat { PageButtons.labelSize(appleScaled: appleScaled) }
    // The label's full-size width, from a hidden copy the shrink never changes.
    @State private var labelWidth: CGFloat = 0

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
                    .font(.system(size: labelSize * stripScale))
                    .foregroundStyle(Color.fgPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(titleLines)
            }
            .frame(maxWidth: .infinity)
            .background {
                Text(title)
                    .font(.system(size: labelSize))
                    .lineLimit(titleLines)
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { labelWidth = $0 }
            }
            .preference(key: StripLabelsKey.self, value: StripLabels(widest: labelWidth, count: 1))
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
            // A list row aligns its content to the leading edge; the full width centres it as on every other page.
            content
                .frame(maxWidth: .infinity)
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
            StatusIcon(asset: isServer ? "tabler-cloud-off" : "tabler-device-mobile-off", style: .title2)
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
    // Set when the title is a track's (the queue): its heart works as every track heart (`trackHeart`).
    var heartTrack: LibraryItem? = nil
    var onFavorite: () -> Void = {}
    @ViewBuilder var trailing: Trailing
    // Follows the title's text.
    @ScaledMetric(relativeTo: .headline) private var heartSize = PageHeader.heartSize
    @Environment(\.fontResolutionContext) private var fontContext
    // The width the row leaves the title.
    @State private var titleWidth: CGFloat = 0

    // SwiftUI splits a word wider than its line with a hyphen ("Gradua-tion" on 40 mm); then the title shrinks just
    // enough for its longest word to fit, and wraps between words as before.
    private var titleFont: Font {
        let normal = Font.headline.weight(.bold)
        guard titleWidth > 0 else { return normal }
        let size = TextSize.current(.headline, in: fontContext)
        let measuring = UIFont.systemFont(ofSize: size, weight: .bold)
        let widest = title.split(whereSeparator: \.isWhitespace)
            .map { (String($0) as NSString).size(withAttributes: [.font: measuring]).width }
            .max() ?? 0
        guard widest > titleWidth else { return normal }
        return .system(size: size * titleWidth / widest * PageHeader.longWordFit, weight: .bold)
    }

    var body: some View {
        // A small gap after the title so it keeps as many letters as it can; the buttons keep theirs.
        HStack(alignment: .center, spacing: PageHeader.titleToButtons) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(Color.fgPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { titleWidth = $0 }
            HStack(spacing: PageHeader.buttonSpacing) {
                if let favorite {
                    let heart = FavoriteHeart(filled: favorite, size: heartSize)
                        .foregroundStyle(Color.fgPrimary)
                        .iconTapArea(heartSize)
                    Group {
                        if let heartTrack {
                            heart.trackHeart(heartTrack, like: onFavorite)
                        } else {
                            Button(action: onFavorite) { heart }.buttonStyle(.plain)
                        }
                    }
                    .accessibilityLabel(favorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
                }
                trailing
            }
        }
    }
}

extension PageTitleRow where Trailing == EmptyView {
    init(title: String, favorite: Bool? = nil, heartTrack: LibraryItem? = nil, onFavorite: @escaping () -> Void = {}) {
        self.init(title: title, favorite: favorite, heartTrack: heartTrack, onFavorite: onFavorite) { EmptyView() }
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

// A page's status icon (the output, a page that couldn't load, nothing playing): a Tabler icon as large as the text style
// it stands beside, at Large, in the text colour.
struct StatusIcon: View {
    let asset: String
    let style: Font.TextStyle

    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(width: TextSize.atLarge(style), height: TextSize.atLarge(style))
            .foregroundStyle(Color.fgPrimary)
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
        // Choose Output: cast, as the AirPlay route's icon (Chap, 23 Nov: not Apple's AirPlay icon)
        "airplayaudio": "tabler-cast",
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
