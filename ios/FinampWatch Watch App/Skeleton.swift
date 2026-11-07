import SwiftUI


/// Shared opacity animation for loading placeholders.
private struct Pulse: ViewModifier {
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
    }
}

extension View {
    func skeletonPulse() -> some View { modifier(Pulse()) }
}

private extension Color {
    static var skeletonFill: Color { ThemeStore.shared.isLight ? .black.opacity(0.09) : .white.opacity(0.14) }
}

/// A text-line loading placeholder.
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

/// Loading placeholders for cover rows.
struct SkeletonCoverRows: View {
    var count = 5
    var coverFraction: CGFloat = 0.24
    var circular = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 10) {
                    Group {
                        if circular {
                            Circle().fill(Color.skeletonFill)
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Color.skeletonFill)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .containerRelativeFrame(.horizontal) { width, _ in width * coverFraction }
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBar(widthFraction: 0.45, height: 12)
                        SkeletonBar(widthFraction: 0.28, height: 9)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .skeletonPulse()
    }
}

/// Loading placeholders for track rows.
struct SkeletonTrackRows: View {
    var count = 6

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                VStack(alignment: .leading, spacing: 5) {
                    SkeletonBar(widthFraction: index.isMultiple(of: 2) ? 0.55 : 0.4, height: 10)
                    HStack {
                        SkeletonBar(widthFraction: 0.3, height: 7)
                        Spacer(minLength: 0)
                        SkeletonBar(widthFraction: 0.1, height: 7)
                    }
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(Color.listFill, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .skeletonPulse()
    }
}

/// Loading placeholder for an album or playlist.
struct SkeletonTrackList: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.skeletonFill)
                        .aspectRatio(1, contentMode: .fit)
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.42 }
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBar(widthFraction: 0.4, height: 13)
                        SkeletonBar(widthFraction: 0.3, height: 13)
                        SkeletonBar(widthFraction: 0.25, height: 9)
                        SkeletonBar(widthFraction: 0.2, height: 8)
                    }
                }
                HStack {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(Color.skeletonFill).frame(width: 22, height: 22).frame(maxWidth: .infinity)
                    }
                }
                .skeletonPulse()
                SkeletonTrackRows(count: 4)
            }
            .skeletonPulse()
        }
    }
}

/// Loading placeholders for Home cards.
struct SkeletonHomeCards: View {
    var count = 3

    var body: some View {
        VStack(spacing: 8) {
            SkeletonBar(widthFraction: 0.4, height: 8)
                .padding(.top, 6)
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.skeletonFill)
                        .aspectRatio(1, contentMode: .fit)
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.2 }
                    SkeletonBar(widthFraction: 0.45, height: 11)
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(Color.listFill, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .skeletonPulse()
    }
}
