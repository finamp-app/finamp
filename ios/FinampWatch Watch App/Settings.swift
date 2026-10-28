import SwiftUI

/// The watch's theme and two of Finamp's settings on the phone.
struct SettingsView: View {
    @Bindable private var theme = ThemeStore.shared
    private var phone = PhoneSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    phoneToggle("Offline Mode", value: \.offline, name: "offline")
                } footer: {
                    Text("This is Finamp's setting on your iPhone: changing it here changes it there. While it's on, only downloaded music plays.")
                        .foregroundStyle(Color.fgSecondary)
                }
                Section {
                    phoneToggle("Enable Transcoding", value: \.transcoding, name: "transcoding")
                } footer: {
                    Text("This is Finamp's setting on your iPhone: changing it here changes it there. Playback follows Finamp's transcoding settings (bitrate and format).")
                        .foregroundStyle(Color.fgSecondary)
                }
                // watchOS Picker labels stay white, making them invisible in the light theme.
                NavigationLink {
                    List(ThemeChoice.allCases) { choice in
                        Button {
                            theme.choice = choice
                        } label: {
                            HStack {
                                Text(choice.title)
                                    .foregroundStyle(Color.fgPrimary)
                                Spacer()
                                if theme.choice == choice {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.finampBlue)
                                }
                            }
                        }
                        .listRowBackground(TrackRowBackground(isPlaying: false))
                    }
                    .navigationTitle("Theme")
                    .containerBackground(Color.appBackground, for: .navigation)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .foregroundStyle(Color.fgPrimary)
                        Text(theme.choice.title)
                            .font(.footnote)
                            .foregroundStyle(Color.fgSecondary)
                    }
                }
                .listRowBackground(TrackRowBackground(isPlaying: false))
            }
            .navigationTitle("Settings")
            // Override watchOS's white form text for the light theme.
            .foregroundStyle(Color.fgPrimary)
            .containerBackground(Color.appBackground, for: .navigation)
        }
        .tint(Color.finampBlue)
        .task {
            if let settings = try? await PhoneConnection.shared.settings() {
                phone.transcoding = settings.transcoding
                phone.offline = settings.offline
            }
        }
    }

    private func phoneToggle(
        _ title: LocalizedStringKey, value: ReferenceWritableKeyPath<PhoneSettings, Bool?>, name: String
    ) -> some View {
        Toggle(title, isOn: Binding(
            get: { phone[keyPath: value] ?? false },
            set: { new in Task { await set(value, name: name, to: new) } }
        ))
        .disabled(phone[keyPath: value] == nil)
        .listRowBackground(TrackRowBackground(isPlaying: false))
    }

    /// Updates optimistically and reverts if the phone cannot be reached.
    private func set(_ value: ReferenceWritableKeyPath<PhoneSettings, Bool?>, name: String, to enabled: Bool) async {
        let previous = phone[keyPath: value]
        phone[keyPath: value] = enabled
        do {
            try await PhoneConnection.shared.setSetting(name, enabled)
        } catch {
            phone[keyPath: value] = previous
        }
    }
}

/// Finamp's settings on the phone as last fetched or pushed; nil until known.
@Observable
final class PhoneSettings {
    static let shared = PhoneSettings()
    var transcoding: Bool?
    var offline: Bool?
}
