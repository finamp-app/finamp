import SwiftUI

struct SettingsView: View {
    @Bindable private var theme = ThemeStore.shared
    private var phone = PhoneSettings.shared
    @State private var reload: ReloadQuestion?
    @AppStorage(TrackInfo.showKey) private var showTrackInfo = TrackInfo.showDefault
    @AppStorage(TrackInfo.shortKey) private var shortTrackInfo = TrackInfo.shortDefault

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
                    Toggle("Advanced Track Info", isOn: $showTrackInfo.animation())
                        .cardRow()
                    if showTrackInfo {
                        Toggle("Short Track Info", isOn: $shortTrackInfo)
                            .subOption()
                            .cardRow()
                    }
                } footer: {
                    Group {
                        if showTrackInfo {
                            Text("The chips you chose in Finamp, under the artist on Playback. Short shows only how the track plays: streamed, downloaded or transcoded, with its format and bitrate.")
                        } else {
                            Text("The chips you chose in Finamp, under the artist on Playback.")
                        }
                    }
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
                        PhoneMessage.show(error)
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
            PhoneMessage.show(error)
        }
    }
}

// The watch's own Playback settings (Settings → Advanced Track Info), read by Settings and Playback.
enum TrackInfo {
    static let showKey = "showChips"
    static let showDefault = true
    static let shortKey = "shortChips"
    static let shortDefault = false
}

// nil until fetched or pushed by the phone.
@Observable
final class PhoneSettings {
    static let shared = PhoneSettings()
    var transcoding: Bool?
    var offline: Bool?
    // Finamp's "prefer adding to favourites over playlists": a track's heart likes on a tap and opens the playlist menu
    // on a long press; off (Finamp's default), the other way round.
    var preferFavorites = false
}
