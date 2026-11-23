import SwiftUI
import WatchKit

// The watch app's layout hub: the design rules below, every layout setting, and the shared components, modifiers and
// custom layouts that apply them. Read the rules before changing how anything looks.
//
// Design rules
// 1. One place. Every layout number and shared layout piece is here, one section per component; pages and components
//    take their sizes from here and carry no numbers of their own. A design change is made here: change a setting, or
//    add a section, never a one-off value in a view. When a change doesn't fit a rule, the rule is changed here first,
//    with its reason, so the design and the code never drift apart.
// 2. watchOS first. watchOS's own parts (top buttons, titles, clock, page dots, List rows, sheets) are never hidden,
//    replaced or moved. Sizes come from watchOS's own values, read while the app runs (`WatchMetrics`), so every watch
//    size and watchOS version brings its own: nothing is set per watch model. The three exceptions are measured and say
//    so: `PlaybackLayout.bottomGap`, `ActivityStatus.clockRowCentre` and `OutputLayout.compact`.
// 3. Margins. m1 is watchOS's own side margin, the line of its top buttons, titles and clock (`scenePadding`, the inset
//    watchOS gives List rows). High-contrast content (text, icons, covers, controls) sits on m1. Low-contrast backgrounds
//    (cards, Home's tiles, the page-button strips) reach out to the card edge: `Margins.cardEdgeShare` of m1 from the
//    screen's edge, never past the edge watchOS draws its own List rows at. That one number is the margin design: 0 leaves
//    the card edge to watchOS (Apple's default), 0.5 puts it at half of m1.
// 4. Text. Apple's text styles, following Text Size on Apple's own curve. The one size of the app's own is `SmallText`,
//    the smallest text, scaled on the same curve. Icons inside a line of text follow that text; standalone icons stay at
//    their size at Large (`fixedIconSize()`); tap areas are fixed (`IconButtons.tapSize`), whatever the icon's size.
// 5. Cards. Content inside a card has the same padding on every side, from watchOS's standard padding (`Cards`).
// 6. Button strips. One component, `ButtonStrip`: equal parts out to the card edge with gaps between, each button
//    centred in its part, one label size per strip.
// 7. Lists. Cards and cover rows are watchOS List rows, so they keep watchOS's scrolling and the shrinking at the top
//    and bottom of the screen: `cardList()` for cards, `coverList()` and `coverListRow()` for covers. A heading over
//    part of a list is watchOS's List section header (`HeadedSection`), the same distance from its first row on every
//    page (`SectionHeadings`). Placeholders (Skeleton.swift) are the real rows with their text redacted, so they follow
//    the same settings.
// 8. Measuring. Sizes are read as layout sizes, and nothing measured is fed back into the size it was measured from
//    (that loops and pins the CPU). Where a size depends on a measurement, the comment says why it can't loop. A screen
//    position is read only to place a drawing that covers the whole screen and takes no part in the layout (Playback's
//    cover shade, `PlaybackLayout.coverShadeStops`).

// MARK: - Margins

enum Margins {
    // The card edge, as a share of m1 from the screen's edge (see the top of this file).
    static let cardEdgeShare: CGFloat = 0

    static let screenSize = WKInterfaceDevice.current().screenBounds.size

    // B (0): watchOS draws the cards. Track cards are plain watchOS List rows (watchOS's insets and row height, text on
    // m1), Home cards put their content on m1, and none of the card padding settings apply.
    static var watchOSDrawsCards: Bool { cardEdgeShare == 0 }

    // The card edge's distance from the screen for a given m1: the share of m1, but no closer to the screen than
    // watchOS's own list rows (`WatchMetrics.listRowEdge`).
    static func cardEdge(m1: CGFloat) -> CGFloat {
        max(cardEdgeShare * m1, WatchMetrics.shared.listRowEdge)
    }

    // How far a card, tile grid or button strip reaches past content on m1: from m1 out to the card edge. m1 is read
    // from the width the content gets, (screen − width) / 2, since pages are centred.
    static func cardBleed(contentWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let m1 = max(0, (screenSize.width - width) / 2)
        return max(0, m1 - cardEdge(m1: m1))
    }
}

// watchOS's values the layout builds on, read once at the app's root (`measuresWatchMetrics()` on the TabView) from
// probes nothing else depends on. 0 until read.
@Observable
final class WatchMetrics {
    static let shared = WatchMetrics()
    // m1, watchOS's side margin.
    var margin: CGFloat = 0
    // SwiftUI's `padding()` with no length.
    var standardPadding: CGFloat = 0
    // How far from the screen's edge watchOS draws its List rows, (screen − row width) / 2, reported by rows whose width
    // nothing in the app changes (`clearListRowReportingEdge()`, track cards).
    var listRowEdge: CGFloat = 0
    // The top inset watchOS gives the app's root (the line of the pages' top buttons' bottom), read at the root
    // (`measuresTopInset()`).
    var topInset: CGFloat = 0

    static func reportRowWidth(_ width: CGFloat) {
        let edge = max(0, (Margins.screenSize.width - width) / 2)
        if width > 0, shared.listRowEdge != edge { shared.listRowEdge = edge }
    }
}

extension View {
    func measuresWatchMetrics() -> some View {
        background {
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    WatchMetrics.shared.margin = max(0, (Margins.screenSize.width - width) / 2)
                }
                .scenePadding(.horizontal)
            Color.clear
                .frame(width: 0, height: 0)
                .padding()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { WatchMetrics.shared.standardPadding = $0 / 2 }
        }
    }

    func measuresTopInset() -> some View {
        background(GeometryReader { proxy in
            Color.clear
                .onAppear { WatchMetrics.shared.topInset = proxy.safeAreaInsets.top }
                .onChange(of: proxy.safeAreaInsets.top) { _, top in WatchMetrics.shared.topInset = top }
        })
    }
}

// MARK: - Cards (track, queue, Settings, Home and search cards)

enum Cards {
    // Content padding inside a card, the same on every side: watchOS's standard padding, made a little larger.
    static let paddingGrowth: CGFloat = 1.05
    static var padding: CGFloat { WatchMetrics.shared.standardPadding * paddingGrowth }

    // Track cards are this share of the height their content plus `padding` all round would give, with the labels
    // unchanged: the padding, still the same on every side, shrinks to make up the difference.
    static let trackHeightShare: CGFloat = 0.95
    static func trackPadding(contentHeight height: CGFloat) -> CGFloat {
        max(0, (trackHeightShare * (height + 2 * padding) - height) / 2)
    }
    // Track cards' top and bottom padding against their side padding.
    static let trackVerticalGrowth: CGFloat = 1.1
    // Then the whole card this much taller, labels unchanged: the top and bottom padding take the difference.
    static let trackCardGrowth: CGFloat = 1.1
    static func trackVerticalPadding(contentHeight height: CGFloat) -> CGFloat {
        let vertical = trackPadding(contentHeight: height) * trackVerticalGrowth
        return (trackCardGrowth * (height + 2 * vertical) - height) / 2
    }
    // The right side grows by the same share as the top and bottom, so the card's gaps keep their proportions.
    static func trackSidePadding(contentHeight height: CGFloat) -> CGFloat {
        let before = trackPadding(contentHeight: height) * trackVerticalGrowth
        guard before > 0 else { return trackPadding(contentHeight: height) }
        return trackPadding(contentHeight: height) * trackVerticalPadding(contentHeight: height) / before
    }
    // A card's side padding when its edge is outside m1 (A1): from the card edge in to m1, so the content inside the card
    // starts on the top buttons' line like all other content. nil when the card ends on m1 (B), whose content keeps the
    // card padding instead.
    static func sidePaddingToLine(m1: CGFloat) -> CGFloat? {
        let toLine = m1 - Margins.cardEdge(m1: m1)
        return toLine > 1 ? toLine : nil
    }

    static let trackCornerRadius: CGFloat = 10
    static let homeCornerRadius: CGFloat = 12
    // Home and search cards: the cover's share of the row's width, and its gap to the title.
    static let homeCoverShare: CGFloat = 0.2
    static let homeCoverToTitle: CGFloat = 8
    // The title at the headline size and in its own bold (semibold) weight.
    static let homeTitleWeight: Font.Weight = .semibold
    // The playing track's row: the accent at this opacity.
    static let playingFillOpacity: Double = 0.22
}

// MARK: - Track rows (Rows.swift `TrackRow`)

enum TrackRows {
    // Album, playlist, favourite and Tracks-tab rows are larger than queue and search rows.
    static let enlargedTextScale: CGFloat = 1.13
    // The artist and duration line against the title.
    static let subtitleScale: CGFloat = 0.75
    // Titles in regular weight, not bold.
    static let titleWeight: Font.Weight = .regular
    static let titleToSubtitle: CGFloat = 1
    static let artistToDuration: CGFloat = 4

    // The heart glyph fills about 85 % of its image, so ×1.2 matches a symbol at the footnote size; then 25 % smaller.
    // It follows the row's text (Text Size), so it fits beside it.
    static let heartScale: CGFloat = 1.2 * 0.75
    static let enlargedHeartScale: CGFloat = 2

    // Finamp's playing bars: centred in the room left of the title, this far from the row's edge and from the title,
    // and 15 pt tall against Finamp's 16 pt titles.
    static let barsGap: CGFloat = 12
    static let barsHeightScale: CGFloat = 0.9
    // The visible gap from the text to the heart matches the playing bars' gap to the title (both measured 10.5 pt):
    // the heart image has about 2.5 pt of clear margin of its own, so the spacing is that much smaller.
    static let textToHeart: CGFloat = 8
    // The row inset the bars assume until it is measured (watchOS's own on the 49 mm).
    static let barsFallbackInset: CGFloat = 14.5
    // Finamp's playing bars: each bar 4/15 of their height wide, at least 2 pt tall, each bouncing at its own speed.
    static let barWidthShare: CGFloat = 4.0 / 15
    static let barMinHeight: CGFloat = 2
    static let barDurations: [Double] = [0.9, 0.8, 0.7]
    // A measured inset outside this range is a measurement gone wrong (`barsFallbackInset` is used instead).
    static let barsInsetRange: ClosedRange<CGFloat> = 2...30
}

// MARK: - Artist chips (Rows.swift `ArtistChip`: Playback, the album page, the queue)

enum ArtistChips {
    // Half of Finamp's 4 pt, so the chip reads closer to a plain label.
    static let cornerRadius: CGFloat = 2
    static let height: CGFloat = 20
    static let textPadding: CGFloat = 5
    // Finamp's chip: the theme's text on 10 % white.
    static let fillOpacity: Double = 0.1
}

// MARK: - Favorites cover (HomePage.swift `FavoritesLogo`)

enum FavoritesCover {
    // Finamp's Favorites tile: the accent colour at 30 %, the heart 36 pt in its 56 pt tile.
    static let fillOpacity: Double = 0.3
    static let iconShare: CGFloat = 36.0 / 56
}

// MARK: - Covers (Artwork.swift `CoverView`, HomePage.swift `FavoritesLogo`)

enum Covers {
    static let cornerRadius: CGFloat = 8
    // A missing cover's icon: Finamp's 24 pt in a list tile's 56 pt cover.
    static let missingIconShare: CGFloat = 0.43
    static let fadeIn: Double = 0.7
}

extension View {
    // A cover's shape: round for artists, rounded corners for the rest.
    func coverClip(circular: Bool) -> some View {
        clipShape(circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: Covers.cornerRadius)))
    }
}

extension Image {
    // An icon in a square of this side, scaled to fit.
    func icon(_ size: CGFloat) -> some View {
        resizable().scaledToFit().frame(width: size, height: size)
    }
}

// An icon centred in a square tile, at a share of its width.
struct CentredIcon: View {
    let asset: String
    let share: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width * share)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Status pages (a message with its icon: Retry, nothing playing, not logged in)

enum StatusPages {
    static let spacing: CGFloat = 8
    static let logoSize: CGFloat = 44
}

// MARK: - Placeholders (Skeleton.swift)

enum Placeholders {
    static let fillOpacity: Double = 0.14
    // The pulse: down to this opacity and back, at this pace.
    static let dimmedOpacity: Double = 0.45
    static let pulseTime: Double = 0.85
}

// MARK: - Finamp's logo tile (Theme.swift `FinampLogoTile`)

enum LogoTile {
    static let insetShare: CGFloat = 0.084
    static let cornerShare: CGFloat = 0.26
}

// MARK: - Cover rows (Albums, Artists, Playlists, Downloads; the artist page and favourite albums and artists)

enum CoverRows {
    // Cover width as a share of the row's width.
    static let albumCoverShare: CGFloat = 0.3
    static let artistCoverShare: CGFloat = 0.28
    static let trackCoverShare: CGFloat = 0.4
    static let coverToText: CGFloat = 10
    // The title against `.title3`.
    static let titleScale: CGFloat = 0.88
    // Cover rows are this far from each other's covers, top and bottom, instead of watchOS's ~13 pt gap, in every cover
    // list (watchOS 26 and later; earlier versions keep watchOS's). Home's lists keep watchOS's.
    static let verticalInset: CGFloat = 1.5
}

// MARK: - Section headings (Home, search, Downloads, the artist page, the favourites pages, the queue, the playlist menu)

enum SectionHeadings {
    // The space between sections (set on the list, `cardList()` / `coverList()`) and above a heading; the heading then
    // sits on watchOS's own space under a section header. Both about half of watchOS's defaults, which are
    // generous on a watch: about 16 pt from a section's last row to the next heading, 9 pt from the heading to its row.
    static let betweenSections: CGFloat = 6
    static let top: CGFloat = 6
    static let toRow: CGFloat = 1
}

// Every heading over part of a List ("RECENTLY PLAYED", "ALBUMS", "UP NEXT"): watchOS's own section header, so watchOS
// places it on m1 and spaces the sections. `placeholder` redacts it, for loading placeholders.
struct HeadedSection<Content: View>: View {
    let title: String
    var placeholder = false
    @ViewBuilder let content: Content

    var body: some View {
        Section { content } header: {
            if placeholder { heading.placeholderRow() } else { heading }
        }
    }

    // Left-aligned as Finamp's headings, in line with the rows below.
    private var heading: some View {
        Text(title.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, SectionHeadings.top)
            .padding(.bottom, SectionHeadings.toRow)
    }
}

// MARK: - Page headers (album, playlist, artist, favourites and queue pages)

enum PageHeader {
    // Between the title row, the cover row and the button strip.
    static let spacing: CGFloat = 10
    // A title word too wide for its line is shrunk to this share of the line, so rounding never tips it back into a
    // hyphenated split (`PageTitleRow`).
    static let longWordFit: CGFloat = 0.97
    // The cover row (`PageCoverRow`): the cover takes this share of the screen's width, its stats the rest of the row,
    // this far apart, the two centred on each other.
    static let coverShare: CGFloat = 1.0 / 3
    static let coverRowAlignment = VerticalAlignment.center
    static let coverToStats: CGFloat = 8
    static let statSpacing: CGFloat = 3
    static let artistChipSpacing: CGFloat = 8
    static let statIconSize: CGFloat = 16
    static let statIconToText: CGFloat = 4
    // Title row: the name, then its heart and download button.
    static let titleToButtons: CGFloat = 4
    static let buttonSpacing: CGFloat = 10
    static let heartSize: CGFloat = 22
    static let downloadIconSize: CGFloat = 22
    static let statIconOpacity: Double = 0.5
}

// The cover row of the album, playlist, artist and favourites pages: the cover at `PageHeader.coverShare` of the
// screen's width, its stats beside it in the rest of the row, aligned by `PageHeader.coverRowAlignment`; the stats may
// run taller than the cover (a small watch, a large Text Size), and the row is then as tall as the stats.
struct PageCoverRow<Cover: View, Info: View>: View {
    @ViewBuilder let cover: Cover
    @ViewBuilder let info: Info

    var body: some View {
        HStack(alignment: PageHeader.coverRowAlignment, spacing: PageHeader.coverToStats) {
            cover.containerRelativeFrame(.horizontal) { width, _ in width * PageHeader.coverShare }
            info.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Settings (Settings.swift)

extension View {
    // An option that belongs to the one above it: shown only while that one is on, its content indented by watchOS's
    // standard padding.
    func subOption() -> some View { padding(.leading, WatchMetrics.shared.standardPadding) }
}

// MARK: - Icon buttons (hearts, the download button)

enum IconButtons {
    // The tap area, independent of the icon: the icon follows the text beside it (Text Size, from its size at Large),
    // the tap area is what a finger needs, the same at every Text Size. Above Apple's 28 pt minimum control size on
    // watchOS (HIG, Accessibility).
    static let tapSize: CGFloat = 34
    // An icon in the top buttons' row.
    static let upperIconSize: CGFloat = 20
}

extension View {
    // A tap area of `IconButtons.tapSize` (or the icon's size, if larger) centred on an icon `size` wide and tall,
    // without changing the layout: the layout keeps the icon's size and the tap area reaches past it on every side.
    func iconTapArea(_ size: CGFloat) -> some View {
        let tap = max(IconButtons.tapSize, size)
        return frame(width: tap, height: tap).contentShape(Rectangle()).padding(-(tap - size) / 2)
    }
}

// MARK: - Request status under the clock (ContentView.swift `phoneActivityIndicator`, PhoneActions.swift `PhoneActivity`)

enum ActivityStatus {
    // Small, like the clock's own status icons; on the top layer of every page and sheet.
    static let iconSize: CGFloat = 10
    // From the top of the page's content up to the icon's bottom: 3 pt above the top buttons' bottom line (the content
    // starts 1 pt above that line on Playback, 40 mm), which reads as in line with the clock.
    static let liftAboveContent: CGFloat = 2
    // On sheets: the middle of the clock's row, from the screen's top. watchOS gives apps no position for its clock,
    // so it's taken from the top inset watchOS gives the app's pages (`WatchMetrics.topInset`, the line of the top
    // buttons' bottom), along the line through two measured watches (clock digits measured on screenshots): 40 mm, inset
    // 40 pt, clock centre 15.5 pt; 49 mm, inset 56.5 pt, centre 28 pt. Sizes between fall between them.
    static func clockRowCentre(topInset: CGFloat) -> CGFloat {
        guard topInset > 0 else { return 15.5 }
        return 15.5 + (topInset - 40) * (28 - 15.5) / (56.5 - 40)
    }
    // The waiting arrows' speed: one turn in this many seconds.
    static let turnTime: Double = 1.2
    // When it shows and how long the failed sign stays: `ConnectionPolicy.Status`.
    // Moving between its places, and appearing or going.
    static let moveTime: Double = 0.3
    static let fadeTime: Double = 0.2
}

// MARK: - Page buttons (Play / Shuffle strips and the queue's buttons; Components.swift `LabeledIconButton`)

// Page buttons sit in a `ButtonStrip` across the content (m1 to m1), spaced by its rule. Labels are the app's smallest
// text (`SmallText`): the icons carry the meaning, the labels help the first few times.
enum PageButtons {
    static let iconSize: CGFloat = 22
    static let iconToLabel: CGFloat = 2
    static let verticalPadding: CGFloat = 4
    // The least space between two buttons; when even that doesn't fit, every label shrinks by the same share, down to
    // `minimumLabelScale`.
    static let labelGap: CGFloat = 6
    static let minimumLabelScale: CGFloat = 0.8
    // Above Large, labels follow Text Size more strongly than Apple's curve, whose steps on watchOS are small: Apple's
    // growth from Large raised to this power (2: where Apple's curve grows by a share, the labels grow by it twice).
    // At Large and below they follow Apple's curve as it is.
    static let labelGrowthAboveLarge: Double = 2
    // The label size from `SmallText` on Apple's curve (`@ScaledMetric(relativeTo: .caption2)` of `SmallText.atLarge`;
    // scaled from the real size, since a scaled metric is rounded to the screen's pixels).
    static func labelSize(appleScaled: CGFloat) -> CGFloat {
        let growth = appleScaled / SmallText.atLarge
        let small = growth > 1 ? SmallText.atLarge * CGFloat(pow(Double(growth), labelGrowthAboveLarge)) : appleScaled
        return small * labelShare
    }
    // The labels against the app's small text, at every Text Size.
    static let labelShare: CGFloat = 1.15
    // The queue's buttons sit this far below the cover row.
    static let queueStripTop: CGFloat = 12
}

// MARK: - Home (HomePage.swift)

enum HomeTiles {
    static let gap: CGFloat = 8
    // watchOS starts content close under the top buttons, closest on small watches; this keeps the tiles clear of the
    // logo and search buttons on every watch.
    static let topPadding: CGFloat = 6
    static let minHeight: CGFloat = 54
    static let padding: CGFloat = 6
    static let cornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 19
    static let iconToLabel: CGFloat = 3
    static let fillOpacity: Double = 0.18
    // Before any quick actions are known: four quiet tiles where they'll be.
    static let placeholderCount = 4
    static let placeholderFillOpacity: Double = 0.08
    static let minimumLabelScale: CGFloat = 0.8
    // Search's "Shuffle All" button.
    static let shuffleAllIconSize: CGFloat = 18
    static let shuffleAllPadding: CGFloat = 10
}

// MARK: - Small text (Playback's times, info chips and volume; the page buttons' labels)

enum SmallText {
    // The app's smallest text, its size at Large; it follows Text Size as `.caption2` does (`@ScaledMetric(relativeTo:
    // .caption2)`, on every watchOS version).
    static let atLarge: CGFloat = 10
}

// MARK: - Playback (PlaybackPage.swift)

enum PlaybackLayout {
    // Title: `.title3` at this scale, bold.
    static let titleScale: CGFloat = 0.9
    static let titleWeight: Font.Weight = .bold

    // Cover shade, black at the top, middle and bottom: the least that keeps the small text at 4.5:1 (WCAG AA) on bright
    // covers (Graduation, AM; 40 and 49 mm). The middle stop is the bottom of the title's line (a share of the screen's
    // height), so the text gets the same shade on every watch and at every Text Size.
    static let coverShade: [Double] = [0.23, 0.63, 0.85]
    static func coverShadeStops(middle: CGFloat) -> [Gradient.Stop] {
        zip(coverShade, [0, min(max(middle, 0), 1), 1]).map { Gradient.Stop(color: .black.opacity($0), location: $1) }
    }

    // The gaps between title, artist row, chips, bar and controls: 9 pt, down to 3 pt on short screens. The gap from
    // the times to the controls is this share of them.
    static let gapMax: CGFloat = 9
    static let gapMin: CGFloat = 3
    static let timesToControlsShare: CGFloat = 0.8

    // Progress bar, midway between the chips and the times: line and dot thickness, drawn height. Its touch strip
    // doesn't grow the layout: none above the bar (the chips never scrub), and over the times below, scaled with the
    // gap under them.
    static let barToTimes: CGFloat = 3
    static let chipsToBar: CGFloat = barToTimes
    static let progressLine: CGFloat = 3.6
    static let progressDot: CGFloat = 10.8
    static let progressHeight: CGFloat = 10
    static let progressTouchBelow: CGFloat = 8 * timesToControlsShare

    // Feature chips 12 pt apart (Finamp's 4 pt padding each side plus 4 pt spacing), down to `chipGapMin` before the
    // line scrolls.
    static let chipGap: CGFloat = 12
    static let chipGapMin: CGFloat = 4

    // Artist row: the chips, then the heart at `chipGap` from them, sized from the chip's height (`ArtistChips.height`)
    // so it follows Text Size as the chips do. The row is the heart's height, the chips centred in it; the heart's tap
    // area reaches past it without taking room (`iconTapArea`), so the title runs the full width.
    static let artistChipSpacing: CGFloat = 6
    static let heartToChip: CGFloat = 1.2
    static let artistToHeart: CGFloat = chipGap

    // Transport: the play button's square and icon, the skip icons and their tap width, the gap between them.
    static let playSize: CGFloat = 48
    static let playIconSize: CGFloat = 35
    static let playCornerRadius: CGFloat = 13
    static let skipIconSize: CGFloat = 31
    static let skipMaxWidth: CGFloat = 53
    static let transportGapMax: CGFloat = 14

    // Room under the Play button for the page dots, whose height differs by model.
    static let bottomGap: CGFloat = {
        switch Int(Margins.screenSize.height) {
        case 197: return 8       // 40 mm
        case 224: return 9       // 44 mm
        case 215, 223: return 11 // 41, 42 mm
        default: return 12       // 45, 46, 49 mm
        }
    }()

    // Over the cover: the volume line, the same lowered, secondary text, the artist chips' text and fill, the Play
    // button's square, and the gradient behind a track with no cover.
    static let volumeOpacity: Double = 0.9
    static let loweredOpacity: Double = 0.6
    static let textOpacity: Double = 0.75
    static let chipTextOpacity: Double = 0.9
    static let chipFillOpacity: Double = 0.16
    static let playFillOpacity: Double = 0.15
    static let noCoverGradientOpacity: Double = 0.45
    // The feature chips' icons, this much larger than their text (the full chips, then the short ones).
    static let chipIconGrowth: CGFloat = 3
    static let shortChipIconGrowth: CGFloat = 2
    // The volume line and the crown's bar stay this long after the crown stops.
    static let volumeShownFor: Double = 1.5
    // The progress bar: the part still to play, the dot while dragged, and VoiceOver's step.
    static let progressRestOpacity: Double = 0.3
    static let progressDotDragScale: CGFloat = 1.5
    static let progressAdjustStep: Double = 0.05
}

// MARK: - Queue header (PlaybackPage.swift `QueueHeader`)

enum QueueLayout {
    static let spacing: CGFloat = 4
    static let titleBottom: CGFloat = 6
    // The cover is as tall as the artist and album lines beside it, at most this share of the row's width; this share
    // until the lines are measured.
    static let coverMaxShare: CGFloat = 0.38
    static let coverInitialShare: CGFloat = 0.24
}

// MARK: - Output sheet (PlaybackPage.swift `OutputSheet`)

enum OutputLayout {
    // Choose Output's cast icon, as a share of its label's text: Tabler's glyph leaves a margin inside its box, so at the
    // text's size it looks smaller than the label.
    static let castToText: CGFloat = 1.3
    static let volumeRowSpacing: CGFloat = 6
    // The 40 and 41 mm watches (under 220 pt tall): the sheet's rows closer together, Choose Output's button lower, so
    // the sheet fits without scrolling.
    static let compact = Margins.screenSize.height < 220
    static var spacing: CGFloat { compact ? 4 : 8 }
    static var buttonPadding: CGFloat { compact ? 5 : 8 }
}

// MARK: - The crown's volume (PlaybackPage.swift `PhoneVolumeCrown`)

enum VolumeCrown {
    // The crown turns a value in this range, from its middle; only its steps are used (`step` per crown click), and a
    // jump of `wrapGuard` or more is the value wrapping at an end.
    static let range: ClosedRange<Double> = 0...1000
    static let start: Double = 500
    static let step: Double = 0.02
    static let wrapGuard: Double = 1
    // The bar beside the crown.
    static let barWidth: CGFloat = 5
    static let barHeight: CGFloat = 40
    static let trackOpacity: Double = 0.25
}

// MARK: - Scrolling text (PlaybackPage.swift `Marquee`)

enum MarqueeLayout {
    // The gap before the text repeats, its speed in points a second, and the pause at the start of each round.
    static let gap: CGFloat = 24
    static let speed: CGFloat = 22
    static let pause: Double = 1.5
}

// MARK: - Playlist menu (PlaylistMenu.swift)

enum PlaylistMenuLayout {
    // The track's cover behind the menu: blurred by watchOS's lightest material (`.ultraThinMaterial`), then darkened,
    // lighter than Finamp's player background (black at 67.5 % in its dark theme) so the cover's colours show.
    static let coverShade: Double = 0.575
}

// MARK: - Shared modifiers and layouts

enum Lists {
    // The minimum row height card and cover lists set so rows can be shorter than watchOS's own minimum. Not 0: watchOS
    // then draws nothing at all for a List with a single row (a library with one playlist showed an empty Playlists
    // tab), while any small positive value works.
    static let minimumRowHeight: CGFloat = 1
}

extension View {
    // A List row with no background of its own (covers, page headers, Home's rows).
    func clearListRow() -> some View { listRowBackground(Color.clear) }

    // A row without a background that also reports watchOS's row edge (`WatchMetrics.listRowEdge`) from its background's
    // width. Only for rows whose width nothing can change: cover rows and Home's cards. Never a row with content widened to
    // the card edge (a button strip, Home's tiles): the card edge depends on this measurement, so that would loop.
    func clearListRowReportingEdge() -> some View {
        listRowBackground(Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { WatchMetrics.reportRowWidth($0) })
    }

    // A List of cards. Rows may be shorter than watchOS's minimum row height, so a card is its content plus the card
    // padding while the gap between cards stays watchOS's.
    func cardList() -> some View { modifier(CardList()) }

    // A track, queue or Settings row as a card: its edge at the card edge; in a `cardList()` its content has the card
    // padding on every side, elsewhere watchOS's.
    func cardRow(isPlaying: Bool = false) -> some View { modifier(CardRow(isPlaying: isPlaying)) }

    func homeCardBackground() -> some View { modifier(HomeCardBackground()) }

    // Widens content on m1 out to the card edge: Home's tile grid and the page-button strips.
    func widenToCardEdge() -> some View { WidenToCardEdge { self } }

    // A List of cover rows (the cover tabs, favourite albums and artists, the artist page): rows may be shorter than
    // watchOS's minimum row height, which is taller than the 49 mm cover, so every row is exactly its cover's height.
    func coverList() -> some View {
        environment(\.defaultMinListRowHeight, Lists.minimumRowHeight).listSectionSpacing(SectionHeadings.betweenSections)
    }

    // A cover row in a cover list: no background and `CoverRows.verticalInset` between covers. Every cover list uses it,
    // so the spacing is set in one place.
    func coverListRow() -> some View { clearListRowReportingEdge().coverRowSpacing() }

    @ViewBuilder
    private func coverRowSpacing() -> some View {
        if #available(watchOS 26.0, *) {
            listRowInsets(.vertical, CoverRows.verticalInset)
        } else {
            self
        }
    }
}

extension EnvironmentValues {
    // watchOS's minimum row height inside a `cardList()`; nil elsewhere.
    @Entry var cardListRowHeight: CGFloat? = nil
}

private struct CardList: ViewModifier {
    @Environment(\.defaultMinListRowHeight) private var watchOSRowHeight

    func body(content: Content) -> some View {
        content
            .environment(\.cardListRowHeight, watchOSRowHeight)
            // Shorter rows than watchOS's only when the app pads its own cards
            .environment(\.defaultMinListRowHeight, Margins.watchOSDrawsCards ? watchOSRowHeight : Lists.minimumRowHeight)
            .listSectionSpacing(SectionHeadings.betweenSections)
    }
}

// watchOS's own row as a card, its edge at the card edge. The row's own edge is (screen − row width) / 2, read from its
// background, whose width insets don't change.
// In a card list the track row draws its card itself (`trackCardFrame`), so the whole card is the button and shrinks
// when pressed; this row only places it at the card edge. The padding comes from the row's content height without
// padding (`TrackCardContentHeightKey`), so it can't change what it's computed from; the sides bring the content to m1
// (`Cards.sidePaddingToLine`). Elsewhere (Settings) the card is the row's background on watchOS's insets.
private struct CardRow: ViewModifier {
    let isPlaying: Bool
    @Environment(\.cardListRowHeight) private var cardList
    @State private var rowWidth: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    private var m1: CGFloat { WatchMetrics.shared.margin }
    private var rowEdge: CGFloat { (Margins.screenSize.width - rowWidth) / 2 }

    private var backgroundInset: CGFloat {
        guard rowWidth > 0, m1 > 0 else { return 0 }
        return max(0, Margins.cardEdge(m1: m1) - rowEdge)
    }

    private var frame: TrackCardFrame? {
        let padding = Cards.trackPadding(contentHeight: contentHeight)
        guard !Margins.watchOSDrawsCards, cardList != nil, rowWidth > 0, m1 > 0, contentHeight > 0, padding > 0 else { return nil }
        let vertical = Cards.trackVerticalPadding(contentHeight: contentHeight)
        let side = Cards.sidePaddingToLine(m1: m1) ?? Cards.trackSidePadding(contentHeight: contentHeight)
        return TrackCardFrame(leading: side, trailing: side, vertical: vertical, isPlaying: isPlaying)
    }

    func body(content: Content) -> some View {
        let frame = frame
        content
            .environment(\.trackCardFrame, frame)
            .onPreferenceChange(TrackCardContentHeightKey.self) { contentHeight = $0 }
            .listRowInsets(frame == nil ? nil : EdgeInsets(top: 0, leading: backgroundInset, bottom: 0, trailing: backgroundInset))
            .listRowBackground(
                Group {
                    if frame == nil {
                        TrackRowBackground(isPlaying: isPlaying).padding(.horizontal, backgroundInset)
                    } else {
                        Color.clear
                    }
                }
                .background(Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    rowWidth = width
                    WatchMetrics.reportRowWidth(width)
                })
            )
    }
}

// The padding a track row draws its card with, inside a card list.
struct TrackCardFrame: Equatable {
    let leading: CGFloat
    let trailing: CGFloat
    let vertical: CGFloat
    let isPlaying: Bool
}

extension EnvironmentValues {
    @Entry var trackCardFrame: TrackCardFrame? = nil
}

// A track row's content height without the card's padding.
struct TrackCardContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// The card is drawn by the row's content: padded by the card padding, then widened from m1 out to the card edge. m1 comes
// from `WatchMetrics`, not from this card's width, which the widening changes. Each Home and search row sets its own
// background, since one set on a group of rows overrides the rows' own.
private struct HomeCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        let m1 = WatchMetrics.shared.margin
        let outward = max(0, m1 - Margins.cardEdge(m1: m1))
        Group {
            if Margins.watchOSDrawsCards {
                // As a watchOS list row: the content on m1, Apple's standard padding above and below
                content.padding(.vertical).padding(.horizontal, outward)
            } else {
                // A1: the content on m1; B: the card padding
                content
                    .padding(.vertical, Cards.padding)
                    .padding(.horizontal, Cards.sidePaddingToLine(m1: m1) ?? Cards.padding)
            }
        }
        .background(RoundedRectangle(cornerRadius: Cards.homeCornerRadius).fill(Color.listFill))
        .padding(.horizontal, -outward)
        .contentShape(Rectangle())
    }
}

// Takes the width its row offers (content on m1) and lays its content out to the card edge on each side. The bleed
// comes from the offered width and nothing is stored, so the wider content can't change the width it came from.
private struct WidenToCardEdge: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        guard let width = proposal.width else { return child.sizeThatFits(proposal) }
        let wide = width + 2 * Margins.cardBleed(contentWidth: width)
        return CGSize(width: width, height: child.sizeThatFits(ProposedViewSize(width: wide, height: proposal.height)).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        let bleed = Margins.cardBleed(contentWidth: bounds.width)
        child.place(at: CGPoint(x: bounds.minX - bleed, y: bounds.minY), anchor: .topLeading,
                    proposal: ProposedViewSize(width: bounds.width + 2 * bleed, height: bounds.height))
    }
}

// A cover row exactly as tall as its cover: the text gets the cover's height to fit into, so the title takes a second
// line only where it fits, and every row (so the gap between covers) is the same at any watch size and Text Size.
// Subviews: the cover, then the text.
struct CoverRowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let cover = subviews[0].sizeThatFits(.unspecified)
        let width = proposal.width ?? cover.width + spacing + subviews[1].sizeThatFits(.unspecified).width
        return CGSize(width: width, height: cover.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cover = subviews[0].sizeThatFits(.unspecified)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(cover))
        subviews[1].place(at: CGPoint(x: bounds.minX + cover.width + spacing, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: max(0, bounds.width - cover.width - spacing), height: bounds.height))
    }
}

// MARK: - Button strips (album, playlist and artist pages, the queue)

// The strip design: the strip reaches the card edge on both sides (like the cards) and is split into equal parts with
// `PageButtons.labelGap` between them; each button's icon and label are centred in its part, and nothing of a button
// goes past its part. All labels in a strip share one size: the app's small text, shrunk by one share for every label
// when the widest doesn't fit its part, down to `PageButtons.minimumLabelScale` (then it wraps within its lines).
// The same for any number of buttons, any watch and any Text Size: only the part's width changes.
struct ButtonStrip<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var width: CGFloat = 0
    @State private var labels = StripLabels()

    // The share every label shrinks by: the part's width against the widest full-size label (measured on hidden copies
    // the shrink never changes, so it can't feed back into itself), rounded down so a hair too wide still fits.
    private var scale: CGFloat {
        guard width > 0, labels.count > 0, labels.widest > 0 else { return 1 }
        let fit = EqualParts.partWidth(width, count: labels.count) / labels.widest
        return fit >= 1 ? 1 : max(PageButtons.minimumLabelScale, (fit * 100).rounded(.down) / 100)
    }

    var body: some View {
        EqualParts { content }
            .environment(\.stripLabelScale, scale)
            .onPreferenceChange(StripLabelsKey.self) { labels = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .widenToCardEdge()
    }
}

extension EnvironmentValues {
    // The share labels shrink by inside a `ButtonStrip`; 1 elsewhere.
    @Entry var stripLabelScale: CGFloat = 1
}

// The widest full-size label in a strip, and how many buttons it has.
struct StripLabels: Equatable {
    var widest: CGFloat = 0
    var count = 0
}

struct StripLabelsKey: PreferenceKey {
    static let defaultValue = StripLabels()
    static func reduce(value: inout StripLabels, nextValue: () -> StripLabels) {
        let next = nextValue()
        value = StripLabels(widest: max(value.widest, next.widest), count: value.count + next.count)
    }
}

// Equal parts with `PageButtons.labelGap` between them, each subview given exactly its part; top-aligned, so a
// two-line label doesn't push its neighbours down.
private struct EqualParts: Layout {
    static func partWidth(_ width: CGFloat, count: Int) -> CGFloat {
        max(0, (width - CGFloat(max(count - 1, 0)) * PageButtons.labelGap) / CGFloat(max(count, 1)))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let part = Self.partWidth(width, count: subviews.count)
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: part, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let part = Self.partWidth(bounds.width, count: subviews.count)
        for (index, subview) in subviews.enumerated() {
            let x = bounds.minX + CGFloat(index) * (part + PageButtons.labelGap)
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: part, height: nil))
        }
    }
}

// MARK: - Text sizes

// Point sizes of text styles, for sizes set relative to text. watchOS 26 resolves Text Size live; older versions read the
// system sizes when the view is created.
enum TextSize {
    static func current(_ style: Font.TextStyle, in context: Font.Context) -> CGFloat {
        if #available(watchOS 26.0, *) {
            return Font.system(style).resolve(in: context).pointSize
        }
        return UIFont.preferredFont(forTextStyle: uiStyle(style)).pointSize
    }

    // At Large, the baseline for sizes that shouldn't follow Text Size (icons).
    static func atLarge(_ style: Font.TextStyle) -> CGFloat {
        if #available(watchOS 26.0, *) {
            var environment = EnvironmentValues()
            environment.dynamicTypeSize = .large
            return Font.system(style).resolve(in: environment.fontResolutionContext).pointSize
        }
        return UIFont.preferredFont(forTextStyle: uiStyle(style)).pointSize
    }

    private static func uiStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .caption2: .caption2
        default: .footnote
        }
    }
}

extension View {
    // Icons stay at Large so only text follows Text Size.
    func fixedIconSize() -> some View {
        dynamicTypeSize(.large)
    }
}
