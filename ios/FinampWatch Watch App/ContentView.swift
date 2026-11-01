import SwiftUI
import WatchKit

/// The watch app's swipe pages, initially showing playback.
enum WatchPage: String, Hashable {
    case home, playback, artists, albums, playlists, tracks, downloads

    static let initial = WatchPage.playback
}

struct ContentView: View {
    @State private var page: WatchPage = .initial

    var body: some View {
        if AccountStore.shared.isLoggedOut {
            LoggedOutView()
        } else {
            pages
                // Rebuild all pages so the previous account's library cannot remain visible.
                .id(AccountStore.shared.generation)
        }
    }

    private var pages: some View {
        TabView(selection: $page) {
            HomePage(isActive: page == .home, onPlay: { page = .playback })
                .tag(WatchPage.home)
            PlaybackPage(isActive: page == .playback)
                .tag(WatchPage.playback)
            LibraryPage(kind: .artists, isActive: page == .artists, onPlay: { page = .playback })
                .tag(WatchPage.artists)
            LibraryPage(kind: .albums, isActive: page == .albums, onPlay: { page = .playback })
                .tag(WatchPage.albums)
            LibraryPage(kind: .playlists, isActive: page == .playlists, onPlay: { page = .playback })
                .tag(WatchPage.playlists)
            LibraryPage(kind: .tracks, isActive: page == .tracks, onPlay: { page = .playback })
                .tag(WatchPage.tracks)
            LibraryPage(kind: .downloads, isActive: page == .downloads, onPlay: { page = .playback })
                .tag(WatchPage.downloads)
        }
        .tabViewStyle(.page)
        .containerBackground(Color.appBackground, for: .tabView)
        .foregroundStyle(Color.fgPrimary)
        .alert(
            Text(verbatim: PhoneMessage.shared.text ?? ""),
            isPresented: Binding(get: { PhoneMessage.shared.text != nil }, set: { if !$0 { PhoneMessage.shared.text = nil } })
        ) {
            Button("OK") {}
        }
    }
}

/// Prompts the user to log in on the phone.
struct LoggedOutView: View {
    var body: some View {
        VStack(spacing: 8) {
            FinampLogoTile(size: 44)
            Text("Connect to Jellyfin")
                .font(.headline)
                .foregroundStyle(Color.fgPrimary)
            Text("Log in to your server in Finamp on your iPhone.")
                .font(.footnote)
                .foregroundStyle(Color.fgSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

#Preview {
    ContentView()
}
