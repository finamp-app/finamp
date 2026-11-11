import SwiftUI

struct LabeledIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = .finampBlue
    var titleLines = 1
    var fills = true
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 2) {
                FinampIcon(systemName: systemImage, size: 22)
                    .font(.title3)
                    .fixedIconSize()
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.fgPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(titleLines)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: fills ? .infinity : nil)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// The buttons at the top of a page and sheet draw Finamp's container tile, shaped like the logo tile, instead of
// watchOS's glass circle: the accent scheme's with accent colours on, Finamp's fixed scheme otherwise.
struct UpperIcon: View {
    let systemName: String
    private let size: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(Color.onContainer)
            .frame(width: size, height: size)
            .background(Color.container, in: RoundedRectangle(cornerRadius: size * 0.26))
    }
}

extension View {
    // Drops watchOS's own circle; UpperIcon draws Finamp's.
    func upperButtonStyle() -> some View {
        buttonStyle(.plain)
    }

    // A sheet's close button as an UpperIcon instead of watchOS's glass one.
    func finampCloseButton(systemName: String = "xmark") -> some View {
        modifier(FinampDismissButton(systemName: systemName, label: "Close", placement: .cancellationAction))
    }

    // A pushed page's back button as an UpperIcon instead of watchOS's glass one.
    func finampBackButton() -> some View {
        navigationBarBackButtonHidden(true)
            .modifier(FinampDismissButton(systemName: "chevron.left", label: "Back", placement: .topBarLeading))
    }
}

private struct FinampDismissButton: ViewModifier {
    let systemName: String
    let label: LocalizedStringKey
    let placement: ToolbarItemPlacement
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: placement) {
                Button {
                    dismiss()
                } label: {
                    UpperIcon(systemName: systemName)
                }
                .upperButtonStyle()
                .accessibilityLabel(label)
            }
        }
    }
}

struct RetryView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
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

// watchOS 26 resolves Text Size live; older versions use system sizes at view creation.
enum TextSize {
    static func current(_ style: Font.TextStyle, in context: Font.Context) -> CGFloat {
        if #available(watchOS 26.0, *) {
            return Font.system(style).resolve(in: context).pointSize
        }
        return UIFont.preferredFont(forTextStyle: uiStyle(style)).pointSize
    }

    // Large is the baseline for relative layout sizes.
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
    // Keep icons at Large size so only text scales.
    func fixedIconSize() -> some View {
        dynamicTypeSize(.large)
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
