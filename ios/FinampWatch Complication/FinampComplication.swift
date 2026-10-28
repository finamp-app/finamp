import SwiftUI
import WidgetKit

/// A static launcher complication that opens Finamp.
@main
struct FinampComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FinampLauncher", provider: LauncherProvider()) { _ in
            LauncherView()
        }
        .configurationDisplayName("Finamp")
        .description("Opens Finamp.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
        // Remove WidgetKit's default inset so the icon fills the circle.
        .contentMarginsDisabled()
    }
}

struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry() }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry()], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date = Date()
}

struct LauncherView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("Finamp", systemImage: "music.note")
            case .accessoryCorner:
                FinampLogo()
                    .padding(3)
                    .widgetLabel { Text("Finamp") }
            default:
                // Tinted faces use the system background.
                ZStack {
                    if renderingMode == .fullColor {
                        Circle().fill(Color(red: 0x00 / 255, green: 0x0B / 255, blue: 0x25 / 255))
                    } else {
                        AccessoryWidgetBackground()
                    }
                    GeometryReader { geometry in
                        FinampLogo()
                            .frame(height: geometry.size.height * 0.75)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if renderingMode == .fullColor {
                            Circle()
                                .strokeBorder(Color(red: 0x3A / 255, green: 0x42 / 255, blue: 0x56 / 255),
                                              lineWidth: geometry.size.height * 0.025)
                                .blur(radius: geometry.size.height * 0.006)
                        }
                    }
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// Vector Finamp logo from images/finamp_cropped.svg, with support for tinted faces.
private struct FinampLogo: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack {
            if renderingMode == .fullColor {
                FinampLogoShape(part: .letter).fill(Self.rgb(0x4F87D3))
                FinampLogoShape(part: .letter).fill(Self.fade(Self.rgb(0x03A2DB), from: (783.228, 484.384), to: (278.88, 516.201)))
                FinampLogoShape(part: .play).fill(Self.rgb(0x8374D3).opacity(0.97647))
                FinampLogoShape(part: .play).fill(Self.fade(Self.rgb(0xAC5FC8), from: (714.565, 446.537), to: (528.174, 481.259)))
            } else {
                FinampLogoShape(part: .letter).fill(.primary)
                FinampLogoShape(part: .play).fill(.primary)
            }
        }
        .aspectRatio(FinampLogoShape.bounds.width / FinampLogoShape.bounds.height, contentMode: .fit)
        .widgetAccentable()
    }

    private static func rgb(_ hex: Int) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Maps gradient endpoints from the SVG's 1024-point canvas into the logo frame.
    private static func fade(_ color: Color, from: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> LinearGradient {
        let b = FinampLogoShape.bounds
        return LinearGradient(
            colors: [color, color.opacity(0)],
            startPoint: UnitPoint(x: (from.0 - b.minX) / b.width, y: (from.1 - b.minY) / b.height),
            endPoint: UnitPoint(x: (to.0 - b.minX) / b.width, y: (to.1 - b.minY) / b.height)
        )
    }
}

/// SVG logo paths scaled to their own bounds.
private struct FinampLogoShape: Shape {
    enum Part { case letter, play }
    let part: Part

    /// Excludes the SVG canvas margins so the logo fills the frame.
    static let bounds = CGRect(x: 129, y: 42, width: 766, height: 940)

    /// Start point, then cubic curves as (control 1, control 2, end).
    private static let letter: (CGPoint, [(CGPoint, CGPoint, CGPoint)]) = (
        CGPoint(x: 328.327, y: 981.999), [
            (CGPoint(x: 512.498, y: 769.508), CGPoint(x: 37.2345, y: 154.135), CGPoint(x: 515.922, y: 233.788)),
            (CGPoint(x: 574.611, y: 242.892), CGPoint(x: 624.828, y: 246.977), CGPoint(x: 710.922, y: 238.42)),
            (CGPoint(x: 830.701, y: 166.298), CGPoint(x: 817.98, y: 145.145), CGPoint(x: 895, y: 72.3472)),
            (CGPoint(x: 501.958, y: 77.1111), CGPoint(x: 650.674, y: 101.298), CGPoint(x: 434.486, y: 64.238)),
            (CGPoint(x: 362.004, y: 51.8126), CGPoint(x: 255.113, y: 22.3151), CGPoint(x: 186.481, y: 62.0322)),
            (CGPoint(x: 111.95, y: 105.162), CGPoint(x: 129.258, y: 240.433), CGPoint(x: 134.543, y: 311.906)),
            (CGPoint(x: 149.935, y: 520.03), CGPoint(x: 183.782, y: 822.738), CGPoint(x: 328.31, y: 982)),
        ]
    )

    private static let play: (CGPoint, [(CGPoint, CGPoint, CGPoint)]) = (
        CGPoint(x: 714.529, y: 446.555), [
            (CGPoint(x: 723.715, y: 468.075), CGPoint(x: 705.091, y: 496.347), CGPoint(x: 630.419, y: 574.243)),
            (CGPoint(x: 550.375, y: 657.745), CGPoint(x: 527.954, y: 672.343), CGPoint(x: 494.87, y: 662.493)),
            (CGPoint(x: 461.781, y: 652.644), CGPoint(x: 450.992, y: 628.162), CGPoint(x: 429.643, y: 514.478)),
            (CGPoint(x: 397.081, y: 341.096), CGPoint(x: 408.151, y: 331.222), CGPoint(x: 578.394, y: 381.894)),
            (CGPoint(x: 664.658, y: 407.572), CGPoint(x: 706.343, y: 427.379), CGPoint(x: 714.529, y: 446.555)),
        ]
    )

    func path(in rect: CGRect) -> Path {
        let bounds = Self.bounds
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        let offset = CGPoint(x: rect.midX - bounds.midX * scale, y: rect.midY - bounds.midY * scale)
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * scale + offset.x, y: p.y * scale + offset.y) }

        let (start, curves) = part == .letter ? Self.letter : Self.play
        var path = Path()
        path.move(to: point(start))
        for (control1, control2, end) in curves {
            path.addCurve(to: point(end), control1: point(control1), control2: point(control2))
        }
        path.closeSubpath()
        return path
    }
}
