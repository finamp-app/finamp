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

enum ThemeChoice: String, CaseIterable, Identifiable {
    case phone, dark, light

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .phone: "Same as iPhone"
        case .dark: "Dark"
        case .light: "Light"
        }
    }
}

// Cache the resolved phone theme for launch, before the phone replies.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var choice = ThemeChoice(rawValue: UserDefaults.standard.string(forKey: "themeChoice") ?? "") ?? .phone {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: "themeChoice") }
    }

    private var phoneIsLight = UserDefaults.standard.bool(forKey: "themeIsLight") {
        didSet { UserDefaults.standard.set(phoneIsLight, forKey: "themeIsLight") }
    }

    var isLight: Bool {
        switch choice {
        case .phone: phoneIsLight
        case .dark: false
        case .light: true
        }
    }

    // Experimental: Finamp's accent colours and tinted backgrounds instead of the original design.
    var accentColors = UserDefaults.standard.bool(forKey: "accentColors") {
        didSet { UserDefaults.standard.set(accentColors, forKey: "accentColors") }
    }

    // Finamp's light and dark schemes as ARGB, kept for launches before the phone replies.
    private var schemes = UserDefaults.standard.dictionary(forKey: "accentSchemes") as? [String: [String: Int]] ?? [:] {
        didSet { UserDefaults.standard.set(schemes, forKey: "accentSchemes") }
    }

    // nil draws the original design.
    var scheme: AccentScheme? {
        guard accentColors, let colors = schemes[isLight ? "light" : "dark"] else { return nil }
        return AccentScheme(colors)
    }

    func applyAccent(_ value: Any?) {
        guard let value = value as? [String: Any] else { return }
        let parsed = value.compactMapValues { colors in
            (colors as? [String: Any])?.compactMapValues { ($0 as? NSNumber)?.intValue }
        }
        if parsed != schemes { schemes = parsed }
    }

    func apply(_ theme: Any?) {
        guard let theme = theme as? String, theme == "light" || theme == "dark" else { return }
        let light = theme == "light"
        if light != phoneIsLight { phoneIsLight = light }
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
    let primary, surface, onSurface, onSurfaceVariant, container, onContainer: Color

    init?(_ argb: [String: Int]) {
        func color(_ name: String) -> Color? {
            argb[name].map { Color(red: Double(($0 >> 16) & 0xFF) / 255, green: Double(($0 >> 8) & 0xFF) / 255, blue: Double($0 & 0xFF) / 255) }
        }
        guard let primary = color("primary"), let surface = color("surface"), let onSurface = color("onSurface"),
              let onSurfaceVariant = color("onSurfaceVariant"), let container = color("container"),
              let onContainer = color("onContainer") else { return nil }
        (self.primary, self.surface, self.onSurface) = (primary, surface, onSurface)
        (self.onSurfaceVariant, self.container, self.onContainer) = (onSurfaceVariant, container, onContainer)
    }
}

extension Color {
    static var appBackground: Color { ThemeStore.shared.scheme?.surface ?? (ThemeStore.shared.isLight ? .white : .black) }
    static var fgPrimary: Color { ThemeStore.shared.scheme?.onSurface ?? (ThemeStore.shared.isLight ? .black : .white) }
    static var fgSecondary: Color {
        ThemeStore.shared.scheme?.onSurfaceVariant ?? (ThemeStore.shared.isLight ? Color(white: 0.42) : Color(white: 0.62))
    }
    static var listFill: Color { ThemeStore.shared.isLight ? .black.opacity(0.045) : .white.opacity(0.09) }
    // primaryContainer / onPrimaryContainer of Finamp's fixed schemes (lib/color_schemes.g.dart).
    static var container: Color {
        ThemeStore.shared.scheme?.container
            ?? (ThemeStore.shared.isLight ? Color(red: 0xC4 / 255, green: 0xE8 / 255, blue: 0xFF / 255)
                : Color(red: 0x00 / 255, green: 0x4C / 255, blue: 0x68 / 255))
    }
    static var onContainer: Color {
        ThemeStore.shared.scheme?.onContainer
            ?? (ThemeStore.shared.isLight ? Color(red: 0x00 / 255, green: 0x1E / 255, blue: 0x2C / 255)
                : Color(red: 0xC3 / 255, green: 0xE7 / 255, blue: 0xFF / 255))
    }
}

struct FinampLogoTile: View {
    var size: CGFloat = 34

    var body: some View {
        let light = ThemeStore.shared.isLight
        Image("FinampLogo")
            .resizable()
            .scaledToFit()
            .padding(size * 0.084)
            .frame(width: size, height: size)
            .background(
                light ? Color.white : Color(red: 0x0F / 255, green: 0x21 / 255, blue: 0x29 / 255),
                in: RoundedRectangle(cornerRadius: size * 0.26)
            )
            .overlay {
                if !light {
                    RoundedRectangle(cornerRadius: size * 0.26)
                        .stroke(Color(red: 0x26 / 255, green: 0x35 / 255, blue: 0x3D / 255), lineWidth: 1)
                }
            }
            .shadow(color: light ? .black.opacity(0.18) : .clear, radius: 3, y: 1)
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
    @ViewBuilder func accentTitle() -> some View {
        if let scheme = ThemeStore.shared.scheme {
            toolbarForegroundStyle(scheme.primary, for: .navigationBar)
        } else {
            self
        }
    }
}
