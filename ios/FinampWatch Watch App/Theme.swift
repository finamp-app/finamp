import SwiftUI

extension Color {
    // Follows phone accent, falling back to Jellyfin blue.
    static var finampBlue: Color { ThemeStore.shared.accent ?? jellyfinBlue }
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

    // Retain the accent for launches before the phone replies.
    private var accentARGB = UserDefaults.standard.object(forKey: "accentARGB") as? Int {
        didSet { UserDefaults.standard.set(accentARGB, forKey: "accentARGB") }
    }

    var accent: Color? {
        accentARGB.map { argb in
            Color(red: Double((argb >> 16) & 0xFF) / 255, green: Double((argb >> 8) & 0xFF) / 255, blue: Double(argb & 0xFF) / 255)
        }
    }

    func applyAccent(_ value: Any?) {
        guard let argb = (value as? NSNumber)?.intValue, argb != accentARGB else { return }
        accentARGB = argb
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

extension Color {
    static var appBackground: Color { ThemeStore.shared.isLight ? .white : .black }
    static var fgPrimary: Color { ThemeStore.shared.isLight ? .black : .white }
    static var fgSecondary: Color { ThemeStore.shared.isLight ? Color(white: 0.42) : Color(white: 0.62) }
    static var listFill: Color { ThemeStore.shared.isLight ? .black.opacity(0.045) : .white.opacity(0.09) }
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
        content.containerBackground(Color.appBackground, for: .navigation)
    }
}
