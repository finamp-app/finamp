import SwiftUI
import WatchKit

// The watch app's layout hub: every layout setting, and the shared modifiers and custom layouts that apply them.
// Pages and components take their numbers from here; each setting says what it does and where it is used.
//
// How a page is laid out
// - m1, watchOS's own side margin: the line of watchOS's top buttons, titles and clock (`scenePadding`, and the inset
//   watchOS gives List rows). Text, icons, covers and controls sit on it. It is read while the app runs
//   (`WatchMetrics`), so every watch size and watchOS version brings its own value; nothing here is per watch model.
// - The card edge: cards, Home's tiles and the page-button strips reach past m1, out to `Margins.cardEdgeShare` of m1
//   from the screen's edge, but never past the edge watchOS draws its own list rows at. That one number is the margin
//   design: 0.5 puts card edges at half of m1 (A1), 1 puts them on m1 with the content (B), 0 at watchOS's row edge (A2).
// - The card padding: content inside a card has the same padding on every side, from watchOS's standard padding
//   (`Cards`).
// - Lists: cards and cover rows are watchOS List rows, so they keep watchOS's scrolling and the shrinking at the top and
//   bottom of the screen. `cardList()` marks a list of cards; cover lists use `coverList()` and `coverListRow()`.
// - Placeholders (Skeleton.swift) are the real rows with their text redacted, so they follow the same settings.
//
// Measuring: sizes are read as layout sizes, never screen positions, and nothing measured is fed back into the size it
// was measured from (that loops and pins the CPU). Where a size depends on a measurement, the comment says why it can't.

// MARK: - Margins

enum Margins {
    // The card edge, as a share of m1 from the screen's edge (see the top of this file).
    static let cardEdgeShare: CGFloat = 0

    static let screenWidth = WKInterfaceDevice.current().screenBounds.width

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
        let m1 = max(0, (screenWidth - width) / 2)
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
        let edge = max(0, (Margins.screenWidth - width) / 2)
        if width > 0, shared.listRowEdge != edge { shared.listRowEdge = edge }
    }
}

extension View {
    func measuresWatchMetrics() -> some View {
        background {
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    WatchMetrics.shared.margin = max(0, (Margins.screenWidth - width) / 2)
                }
                .scenePadding(.horizontal)
            Color.clear
                .frame(width: 0, height: 0)
                .padding()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { WatchMetrics.shared.standardPadding = $0 / 2 }
        }
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
}

// MARK: - Artist chips (Rows.swift `ArtistChip`: Playback, the album page, the queue)

enum ArtistChips {
    // Half of Finamp's 4 pt, so the chip reads closer to a plain label.
    static let cornerRadius: CGFloat = 2
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
    // Downloads: a section heading above the first row of its kind.
    static let headingToRow: CGFloat = 6
}

// MARK: - Page headers (album, playlist, artist, favourites and queue pages)

enum PageHeader {
    // Between the title row, the cover row and the button strip.
    static let spacing: CGFloat = 10
    // The cover and its stats share the row in halves, this far apart.
    static let coverToStats: CGFloat = 8
    static let statSpacing: CGFloat = 3
    static let artistChipSpacing: CGFloat = 8
    // Favourites pages: the logo row to the section heading under it.
    static let favoritesLogoToHeading: CGFloat = 6
    static let statIconSize: CGFloat = 16
    static let statIconToText: CGFloat = 4
    // Title row: the name, then its heart and download button.
    static let titleToButtons: CGFloat = 4
    static let buttonSpacing: CGFloat = 10
    static let heartSize: CGFloat = 22
    static let downloadIconSize: CGFloat = 22
    // Above a section heading ("ALBUMS", "TRACKS", "UP NEXT").
    static let sectionHeaderTop: CGFloat = 6
}

// MARK: - Icon buttons (hearts, the download button)

enum IconButtons {
    // The tap area, independent of the icon: the icon follows the text beside it (Text Size, from its size at Large),
    // the tap area is what a finger needs, the same at every Text Size. Above Apple's 28 pt minimum control size on
    // watchOS (HIG, Accessibility).
    static let tapSize: CGFloat = 34
}

extension View {
    // A tap area of `IconButtons.tapSize` (or the icon's size, if larger) centred on an icon `size` wide and tall,
    // without changing the layout: the layout keeps the icon's size and the tap area reaches past it on every side.
    func iconTapArea(_ size: CGFloat) -> some View {
        let tap = max(IconButtons.tapSize, size)
        return frame(width: tap, height: tap).contentShape(Rectangle()).padding(-(tap - size) / 2)
    }
}

extension View {
    // Reads `WatchMetrics.topInset` at the app's root.
    func measuresTopInset() -> some View {
        background(GeometryReader { proxy in
            Color.clear
                .onAppear { WatchMetrics.shared.topInset = proxy.safeAreaInsets.top }
                .onChange(of: proxy.safeAreaInsets.top) { _, top in WatchMetrics.shared.topInset = top }
        })
    }
}

// MARK: - Request status under the clock (ContentView.swift `phoneActivityIndicator`, PhoneActions.swift `PhoneActivity`)

enum ActivityStatus {
    // Small, like the clock's own status icons; on the top layer of every page and sheet.
    static let iconSize: CGFloat = 10
    // From the top of the page's content up to the icon's bottom: 3 pt above the top buttons' bottom line (the content
    // starts 1 pt above that line on Playback, 40 mm), which yalit saw as in line with the clock (19 Nov, Ultra 3).
    static let liftAboveContent: CGFloat = 2
    // Normal requests take 0.1-0.6 s on the devices; the status shows only for one still waiting after this.
    static let showAfter: Duration = .seconds(1)
    // On sheets: the middle of the clock's row, from the screen's top. watchOS gives apps no position for its clock,
    // so it's taken from the top inset watchOS gives the app's pages (`WatchMetrics.topInset`, the line of the top
    // buttons' bottom), along the line through two measured watches (19 Nov, clock digits by screenshot): 40 mm, inset
    // 40 pt, clock centre 15.5 pt; 49 mm, inset 56.5 pt, centre 28 pt. Sizes between fall between them.
    static func clockRowCentre(topInset: CGFloat) -> CGFloat {
        guard topInset > 0 else { return 15.5 }
        return 15.5 + (topInset - 40) * (28 - 15.5) / (56.5 - 40)
    }
    // The waiting arrows' speed: one turn in this many seconds.
    static let turnTime: Double = 1.2
    // How long the failed sign stays, unless a request gets through first.
    static let failedFor: Duration = .seconds(4)
}

// MARK: - Page buttons (Play / Shuffle strips and the queue's buttons; Components.swift `LabeledIconButton`)

enum PageButtons {
    static let iconSize: CGFloat = 22
    static let iconToLabel: CGFloat = 2
    static let verticalPadding: CGFloat = 4
    // Labels keep at least this much space between them; a label that doesn't fit then shrinks, down to
    // `minimumLabelScale`, before it is cut. In a `sameLabelSize()` strip all labels share the smallest label's size.
    static let labelGap: CGFloat = 6
    static let minimumLabelScale: CGFloat = 0.8
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
}

// MARK: - Playback (PlaybackPage.swift)

enum PlaybackLayout {
    // The title against `.title3`; small text (times, chips, volume) at 10 pt at Large Text Size, scaling with it.
    static let titleScale: CGFloat = 0.9
    static let smallTextAtLarge: CGFloat = 10
    // The gaps between title, artist, chips and bar, and the controls: 9 pt, shrinking to 3 pt on short screens.
    static let gapMax: CGFloat = 9
    static let gapMin: CGFloat = 3
    static let chipsToBar: CGFloat = 6
    static let barToTimes: CGFloat = 3
    // The heart beside the artist line (at Large; it follows the artist's text), and the gap the title and artist
    // leave between themselves and its tap area.
    static let heartSize: CGFloat = 26
    static let heartGap: CGFloat = 6
    // Transport: the play button's square and icon, the skip icons and their tap width, the gap between them.
    static let playSize: CGFloat = 48
    static let playIconSize: CGFloat = 35
    static let playCornerRadius: CGFloat = 13
    static let skipIconSize: CGFloat = 31
    static let skipMaxWidth: CGFloat = 53
    static let transportGapMax: CGFloat = 14
    // Feature chips 12 pt apart (Finamp's 4 pt padding each side plus 4 pt spacing); short chips shrink their gaps to
    // `chipGapMin` before the line scrolls.
    static let chipGap: CGFloat = 12
    static let chipGapMin: CGFloat = 4
    static let artistChipSpacing: CGFloat = 6
    // Room under the Play button for the page dots, whose height differs by model.
    static let bottomGap: CGFloat = {
        switch Int(WKInterfaceDevice.current().screenBounds.height) {
        case 197: return 8       // 40 mm
        case 224: return 9       // 44 mm
        case 215, 223: return 11 // 41, 42 mm
        default: return 12       // 45, 46, 49 mm
        }
    }()
    // Progress bar: line and dot thickness, and the drawn height.
    static let progressLine: CGFloat = 3.6
    static let progressDot: CGFloat = 10.8
    static let progressHeight: CGFloat = 10
    // The bar's touch strip reaches past it without making the layout taller: not above the bar's own frame (touching
    // the chips or just under them never scrubs), and this far down over the times.
    static let progressTouchAbove: CGFloat = 0
    static let progressTouchBelow: CGFloat = 8
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

// MARK: - Shared modifiers and layouts

enum Lists {
    // The minimum row height card and cover lists set so rows can be shorter than watchOS's own minimum. Not 0: watchOS
    // then draws nothing at all for a List with a single row (a library with one playlist showed an empty Playlists
    // tab), while any small positive value works.
    static let minimumRowHeight: CGFloat = 1
}

extension View {
    // A List row with no background of its own (covers, headers, headings, Home's rows).
    func clearListRow() -> some View { listRowBackground(Color.clear) }

    // A row without a background that also reports watchOS's row edge (`WatchMetrics.listRowEdge`) from its background's
    // width. Only for rows whose width nothing can change: headings and cover rows. Never a row with content widened to
    // the card edge (a button strip, Home's tiles): the card edge depends on this measurement, so that would loop.
    func clearListRowReportingEdge() -> some View {
        listRowBackground(Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { WatchMetrics.reportRowWidth($0) })
    }

    // A List of cards. Rows may be shorter than watchOS's minimum row height, so a card is its content plus the card
    // padding while the gap between cards stays watchOS's.
    func cardList() -> some View { modifier(CardList()) }

    // A non-card row in a card list that keeps watchOS's row height (a heading), so the list's spacing stays watchOS's.
    func keepsWatchOSRowHeight() -> some View { modifier(KeepsWatchOSRowHeight()) }

    // A track, queue or Settings row as a card: its edge at the card edge; in a `cardList()` its content has the card
    // padding on every side, elsewhere watchOS's.
    func cardRow(isPlaying: Bool = false) -> some View { modifier(CardRow(isPlaying: isPlaying)) }

    // A Home or search card's background.
    func homeCardBackground() -> some View { modifier(HomeCardBackground()) }

    // Widens content on m1 out to the card edge: Home's tile grid and the page-button strips.
    func widenToCardEdge() -> some View { WidenToCardEdge { self } }

    // A List of cover rows (the cover tabs, favourite albums and artists, the artist page): rows may be shorter than
    // watchOS's minimum row height, which is taller than the 49 mm cover, so every row is exactly its cover's height.
    func coverList() -> some View { environment(\.defaultMinListRowHeight, Lists.minimumRowHeight) }

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
    }
}

private struct KeepsWatchOSRowHeight: ViewModifier {
    @Environment(\.cardListRowHeight) private var rowHeight

    func body(content: Content) -> some View {
        content.frame(minHeight: rowHeight)
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
    private var rowEdge: CGFloat { (Margins.screenWidth - rowWidth) / 2 }

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


// MARK: - Page-button labels sharing one size

extension View {
    // All labels in a button strip at the size of the one that has to shrink most (`PageButtons`). Used by the album,
    // playlist and artist strips.
    func sameLabelSize() -> some View { modifier(SameLabelSize()) }
}

extension EnvironmentValues {
    // The shared label scale inside a `sameLabelSize()` strip; nil elsewhere, where labels shrink on their own.
    @Entry var stripLabelScale: CGFloat? = nil
}

// Each button reports how far its label must shrink (from its full-size width, measured on a hidden copy the shared
// size never changes); the strip takes the smallest, rounded down so a label measured a hair too wide still fits.
struct StripLabelScaleKey: PreferenceKey {
    static let defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = min(value, nextValue()) }
}

private struct SameLabelSize: ViewModifier {
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .environment(\.stripLabelScale, scale)
            .onPreferenceChange(StripLabelScaleKey.self) {
                scale = max(PageButtons.minimumLabelScale, ($0 * 100).rounded(.down) / 100)
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
        case .title3: .title3
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
