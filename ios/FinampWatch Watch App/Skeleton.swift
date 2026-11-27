import SwiftUI

private struct Pulse: ViewModifier {
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? Placeholders.dimmedOpacity : 1)
            .animation(.easeInOut(duration: Placeholders.pulseTime).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
    }
}

extension View {
    func skeletonPulse() -> some View { modifier(Pulse()) }
}

extension Color {
    static var skeletonFill: Color { .white.opacity(Placeholders.fillOpacity) }
}

struct SkeletonBar: View {
    var widthFraction: CGFloat = 1
    var height: CGFloat = 10

    var body: some View {
        Capsule()
            .fill(Color.skeletonFill)
            .frame(height: height)
            .containerRelativeFrame(.horizontal) { width, _ in width * widthFraction }
    }
}

// Placeholders are the real rows and cards with SwiftUI's placeholder redaction, placed in the same lists with the same
// row modifiers as the content they stand in for, so their sizes, padding and gaps come from the same settings
// (Layout.swift) and can't drift from the real ones.
// Each is a set of List rows: use it inside a List.

extension LibraryItem {
    // Stand-in text; only its length shapes the grey bars.
    static func placeholder(_ index: Int) -> LibraryItem {
        LibraryItem(
            id: "placeholder-\(index)",
            name: index.isMultiple(of: 2) ? "Placeholder title" : "Placeholder",
            subtitle: "Placeholder artist",
            artworkKey: "",
            duration: 200
        )
    }
}

extension View {
    func placeholderRow() -> some View {
        redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .skeletonPulse()
    }
}

// Cover rows (Albums, Artists, Playlists, Downloads, the artist page, favourite albums and artists). `sectionHeader`
// puts them under a heading, as Downloads does.
struct SkeletonCoverRows: View {
    var count = 5
    var coverShare: CGFloat
    var circular = false
    var sectionHeader = false

    var body: some View {
        if sectionHeader {
            HeadedSection(title: "Placeholder", placeholder: true) { rows }
        } else {
            rows
        }
    }

    private var rows: some View {
        ForEach(0..<count, id: \.self) { index in
            CoverRow(item: .placeholder(index), coverShare: coverShare, circular: circular)
                .placeholderRow()
                .coverListRow()
        }
    }
}

// Track cards (album, playlist and favourite tracks, the Tracks tab, the queue, search); `hearts` and `enlarged` as
// the real rows of that list have them.
struct SkeletonTrackRows: View {
    var count = 6
    var hearts = false
    var enlarged = false

    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            TrackRow(track: .placeholder(index), heart: hearts, enlarged: enlarged)
                .placeholderRow()
                .cardRow()
        }
    }
}

// Home's first section while it loads: a heading and its cards.
struct SkeletonHomeCards: View {
    var count = 3

    var body: some View {
        HeadedSection(title: "Placeholder", placeholder: true) {
            ForEach(0..<count, id: \.self) { index in
                HomeCard(item: .placeholder(index))
                    .placeholderRow()
                    .clearListRow()
            }
        }
    }
}
