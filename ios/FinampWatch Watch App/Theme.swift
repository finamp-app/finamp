import SwiftUI

extension Color {
    // Finamp's accent with accent colours on; the original fixed blue otherwise.
    static var finampBlue: Color { ThemeStore.shared.scheme?.primary ?? jellyfinBlue }
    static let jellyfinBlue = Color(red: 0x00 / 255, green: 0xA4 / 255, blue: 0xDC / 255)
    static let finampPurple = Color(red: 0xAA / 255, green: 0x5C / 255, blue: 0xC3 / 255)
}

extension ShapeStyle where Self == LinearGradient {
    static var finampGradient: LinearGradient {
        LinearGradient(colors: [.finampPurple, .jellyfinBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// The watch is always dark, like watchOS itself; only the accent follows Finamp.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    // Finamp's accent colours and tinted backgrounds instead of the default design.
    var accentColors = UserDefaults.standard.bool(forKey: "accentColors") {
        didSet { UserDefaults.standard.set(accentColors, forKey: "accentColors") }
    }

    // Finamp's light and dark schemes as ARGB, kept for launches before the phone replies.
    private var schemes = UserDefaults.standard.dictionary(forKey: "accentSchemes") as? [String: [String: Int]] ?? [:] {
        didSet { UserDefaults.standard.set(schemes, forKey: "accentSchemes") }
    }

    // nil draws the default design.
    var scheme: AccentScheme? {
        guard accentColors, let colors = schemes["dark"] else { return nil }
        return AccentScheme(colors)
    }

    // watchOS draws a switch's knob white: tint switches with the light scheme's primary, which Material pairs with white.
    var switchTint: Color? {
        guard accentColors, let colors = schemes["light"] else { return nil }
        return AccentScheme(colors)?.primary
    }

    func applyAccent(_ value: Any?) {
        guard let value = value as? [String: Any] else { return }
        let parsed = value.compactMapValues { colors in
            (colors as? [String: Any])?.compactMapValues { ($0 as? NSNumber)?.intValue }
        }
        if parsed != schemes { schemes = parsed }
    }
}

// Clears cached data on logout or account change.
@Observable
final class AccountStore {
    static let shared = AccountStore()

    // nil until reported; empty means logged out.
    private(set) var account = UserDefaults.standard.string(forKey: "account")
    // Force pages to rebuild for a different account.
    private(set) var generation = 0

    var isLoggedOut: Bool { account == "" }

    func apply(_ value: Any?) {
        guard let new = value as? String, new != account else { return }
        let hadAccount = account != nil
        account = new
        UserDefaults.standard.set(new, forKey: "account")
        // Preserve data on first account discovery, but always clear on logout.
        guard hadAccount || new.isEmpty else { return }
        ArtworkStore.shared.removeAll()
        FavoriteOverrides.shared.removeAll()
        QuickAction.cached = nil
        NowPlayingStore.shared.nowPlaying = NowPlaying()
        generation += 1
    }
}

// The colours of Finamp's scheme the watch draws with, used in the same Material pairs as Finamp's screens.
struct AccentScheme {
    let primary, onPrimary, surface, onSurface, onSurfaceVariant: Color

    init?(_ argb: [String: Int]) {
        func color(_ name: String) -> Color? { argb[name].map(Color.init(argb:)) }
        guard let primary = color("primary"), let surface = color("surface"), let onSurface = color("onSurface"),
              let onSurfaceVariant = color("onSurfaceVariant") else { return nil }
        (self.primary, self.surface, self.onSurface) = (primary, surface, onSurface)
        onPrimary = color("onPrimary") ?? .white
        self.onSurfaceVariant = onSurfaceVariant
    }
}

extension Color {
    // Flutter's ARGB; the watch draws these opaque.
    init(argb: Int) {
        self.init(red: Double((argb >> 16) & 0xFF) / 255, green: Double((argb >> 8) & 0xFF) / 255, blue: Double(argb & 0xFF) / 255)
    }

    static var appBackground: Color { ThemeStore.shared.scheme?.surface ?? .black }
    static var fgPrimary: Color { ThemeStore.shared.scheme?.onSurface ?? .white }
    static var fgSecondary: Color { ThemeStore.shared.scheme?.onSurfaceVariant ?? Color(white: 0.62) }
    static var listFill: Color { .white.opacity(0.09) }
}

struct FinampLogoTile: View {
    var size: CGFloat = 34

    var body: some View {
        Image("FinampLogo")
            .resizable()
            .scaledToFit()
            .padding(size * LogoTile.insetShare)
            .frame(width: size, height: size)
            .background(
                Color(red: 0x0F / 255, green: 0x21 / 255, blue: 0x29 / 255),
                in: RoundedRectangle(cornerRadius: size * LogoTile.cornerShare)
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * LogoTile.cornerShare)
                    .stroke(Color(red: 0x26 / 255, green: 0x35 / 255, blue: 0x3D / 255), lineWidth: 1)
            }
    }
}

extension View {
    // Avoid watchOS's default black navigation background.
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
}

private struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(Color.appBackground, for: .navigation)
            .accentTitle()
    }
}

extension View {
    // watchOS draws titles in the asset's fixed accent; with accent colours on, use Finamp's.
    // Always applied (the asset's colour when off), so flipping the setting doesn't rebuild the page and reset its scroll.
    func accentTitle() -> some View {
        toolbarForegroundStyle(ThemeStore.shared.scheme?.primary ?? Color("AccentColor"), for: .navigationBar)
    }
}
