import SwiftUI

struct SettingsView: View {
    @Bindable private var theme = ThemeStore.shared
    private var phone = PhoneSettings.shared
    @State private var reload: ReloadQuestion?

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
                    .accentTitle()
                    .finampBackButton()
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
                Section {
                    Toggle("Accent Colors (Experimental)", isOn: $theme.accentColors)
                        .listRowBackground(TrackRowBackground(isPlaying: false))
                } footer: {
                    Text("Uses your accent color from Finamp, with matching backgrounds. Turn it off for the original look.")
                        .foregroundStyle(Color.fgSecondary)
                }
            }
            .navigationTitle("Settings")
            .accentTitle()
            .finampCloseButton(systemName: "chevron.left")
            // Override watchOS's white form text for the light theme.
            .foregroundStyle(Color.fgPrimary)
            .containerBackground(Color.appBackground, for: .navigation)
        }
        .tint(ThemeStore.shared.switchTint ?? Color.finampBlue)
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
        .listRowBackground(TrackRowBackground(isPlaying: false))
    }

    // Revert if phone cannot be reached.
    private func set(_ value: ReferenceWritableKeyPath<PhoneSettings, Bool?>, name: String, to enabled: Bool) async {
        let previous = phone[keyPath: value]
        phone[keyPath: value] = enabled
        do {
            reload = try await PhoneConnection.shared.setSetting(name, enabled)
        } catch {
            phone[keyPath: value] = previous
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
