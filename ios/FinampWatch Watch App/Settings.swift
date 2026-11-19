import SwiftUI

struct SettingsView: View {
    @Bindable private var theme = ThemeStore.shared
    private var phone = PhoneSettings.shared
    @State private var reload: ReloadQuestion?
    @AppStorage("shortChips") private var shortChips = false

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
                Section {
                    Toggle("Short Track Info", isOn: $shortChips)
                        .cardRow()
                } footer: {
                    Text("Shows only how the track plays on Playback: streamed, downloaded or transcoded, with its format and bitrate. Off shows every chip you chose in Finamp.")
                        .foregroundStyle(Color.fgSecondary)
                }
                Section {
                    Toggle("Accent Colors (Experimental)", isOn: $theme.accentColors)
                        .cardRow()
                } footer: {
                    Text("Uses your accent color from Finamp, with matching backgrounds. Turn it off for the original look.")
                        .foregroundStyle(Color.fgSecondary)
                }
            }
            // The toggles in Finamp blue (the accent with Accent Colors on).
            .tint(ThemeStore.shared.switchTint ?? Color.finampBlue)
            .navigationTitle("Settings")
            .accentTitle()
            // Finamp's text colour instead of watchOS's white.
            .foregroundStyle(Color.fgPrimary)
            .containerBackground(Color.appBackground, for: .navigation)
        }
        // watchOS's close button as every top button: glass with Accent Colors off, the accent with it on.
        .tint(ThemeStore.shared.switchTint)
        .alert(
            Text(verbatim: reload?.text ?? ""),
            isPresented: Binding(get: { reload != nil }, set: { if !$0 { reload = nil } }),
            presenting: reload
        ) { question in
            Button(question.button) {
                Task {
                    do {
                        try await PhoneConnection.shared.reloadQueue(archive: question.archive)
                    } catch {
                        PhoneMessage.shared.text = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
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
        .cardRow()
    }

    // Revert if phone cannot be reached.
    private func set(_ value: ReferenceWritableKeyPath<PhoneSettings, Bool?>, name: String, to enabled: Bool) async {
        let previous = phone[keyPath: value]
        phone[keyPath: value] = enabled
        do {
            reload = try await PhoneConnection.shared.setSetting(name, enabled)
        } catch {
            phone[keyPath: value] = previous
            PhoneMessage.shared.text = error.localizedDescription
        }
    }
}

// nil until fetched or pushed by the phone.
@Observable
final class PhoneSettings {
    static let shared = PhoneSettings()
    var transcoding: Bool?
    var offline: Bool?
}
