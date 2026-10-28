import SwiftUI

/// An outline action button with a label below.
struct LabeledIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = .finampBlue
    /// Allows long labels to wrap instead of shrinking.
    var titleLines = 1
    /// Fills the row when true; otherwise uses the button's intrinsic width.
    var fills = true
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 2) {
                FinampIcon(systemName: systemImage, size: 22)
                    .font(.title3)
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

/// An error message with a retry action.
struct RetryView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isServer ? "wifi.slash" : "iphone.slash")
                .font(.title2)
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

    /// What to do about it, for the failures that have a remedy.
    private var hint: LocalizedStringKey? {
        if isServer { return "Turn on Offline Mode in Settings to play your downloads" }
        let phoneUnavailable = [PhoneError.notReachable.localizedDescription, PhoneError.noAnswer.localizedDescription, "Finamp is still starting"]
        return phoneUnavailable.contains(message) ? "Open Finamp on your iPhone" : nil
    }
}

/// Uses Finamp's Tabler icons where they differ from SF Symbols.
struct FinampIcon: View {
    let systemName: String
    /// Tabler icon side in points; these images do not scale with the font.
    let size: CGFloat

    private static let tabler = [
        "shuffle": "tabler-arrows-shuffle",
        "heart.circle": "tabler-heart-question",
        "clock.arrow.circlepath": "tabler-restore",
        "sparkles": "tabler-radio",
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
