import SwiftUI

enum WatchPage: String, Hashable {
    case home, playback, artists, albums, playlists, tracks, downloads

    static let initial = WatchPage.playback
}

struct ContentView: View {
    @State private var page = WatchPage.initial
    // Where the clock is on the screen in front (`clockPlace`); library pages and the login screen have it right.
    @State private var clockPlace = ActivityPlace.underClockOnRight
    // Dimmed or wrist down: nothing on screen needs live updates.
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        content
            .measuresTopInset()
            .onPreferenceChange(ClockPlaceKey.self) { clockPlace = $0 ?? .underClockOnRight }
            // Above the login screen too: an action started before a logout can still be waiting.
            .phoneActivityIndicator(AccountStore.shared.isLoggedOut ? .underClockOnRight : clockPlace)
    }

    @ViewBuilder
    private var content: some View {
        if AccountStore.shared.isLoggedOut {
            LoggedOutView()
        } else {
            pages
                // Rebuild all pages so the previous account's library cannot remain visible.
                .id(AccountStore.shared.generation)
                // For the log: watchOS limits what the app may do while dimmed, wrist down or in the background.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    PhoneConnection.shared.noteScene("\(phase)")
                    WatchLog.info("scene \(phase)")
                    if phase != .active { WatchLog.shared.flush() }
                }
                .onChange(of: isLuminanceReduced) { _, dimmed in WatchLog.info("dimmed \(dimmed)") }
                .onChange(of: page) { _, page in WatchLog.fine("page \(page.rawValue)") }
        }
    }

    // Playback started from another page: go to the player itself, also when Playback still had an album or artist
    // page open from before (it keeps its own stack of pages).
    @State private var playStarted = 0

    private func showPlayer() {
        playStarted += 1
        page = .playback
    }

    private var pages: some View {
        TabView(selection: $page) {
            HomePage(isActive: page == .home, onPlay: showPlayer)
                .inFront(page == .home)
                .tag(WatchPage.home)
            // Inactive while dimmed: no polling or ticking, and one refresh when the screen is raised
            PlaybackPage(isActive: page == .playback && scenePhase == .active, playStarted: playStarted)
                .inFront(page == .playback)
                .tag(WatchPage.playback)
            LibraryPage(kind: .artists, isActive: page == .artists, onPlay: showPlayer)
                .tag(WatchPage.artists)
            LibraryPage(kind: .albums, isActive: page == .albums, onPlay: showPlayer)
                .tag(WatchPage.albums)
            LibraryPage(kind: .playlists, isActive: page == .playlists, onPlay: showPlayer)
                .tag(WatchPage.playlists)
            LibraryPage(kind: .tracks, isActive: page == .tracks, onPlay: showPlayer)
                .tag(WatchPage.tracks)
            LibraryPage(kind: .downloads, isActive: page == .downloads, onPlay: showPlayer)
                .tag(WatchPage.downloads)
        }
        .tabViewStyle(.page)
        .measuresWatchMetrics()
        .containerBackground(Color.appBackground, for: .tabView)
        .foregroundStyle(Color.fgPrimary)
        // System controls follow Finamp's accent with accent colours on; the asset's fixed blue otherwise
        .tint(ThemeStore.shared.switchTint)
        .playlistMenuHost()
        .phoneMessageAlert()
    }
}

extension View {
    // Shows `PhoneMessage` (a failed action) as an alert. Sheets attach it too: an alert can't appear over a sheet from
    // the page underneath.
    func phoneMessageAlert() -> some View {
        alert(
            Text(verbatim: PhoneMessage.shared.text ?? ""),
            isPresented: Binding(get: { PhoneMessage.shared.text != nil }, set: { if !$0 { PhoneMessage.shared.text = nil } })
        ) {
            Button("OK") {}
        }
    }
}

extension View {
    // The status of requests you made (`PhoneActivity`), above everything on the page, centred across the screen; only
    // its height depends on the clock (`ActivityPlace.iconCentre`). One view for every place, so a page change moves it
    // smoothly. Sheets attach it too, as they do the alert.
    func phoneActivityIndicator(_ place: ActivityPlace = .sheet) -> some View {
        overlay(alignment: .top) {
            PhoneActivityIndicator()
                .frame(maxWidth: .infinity)
                .frame(height: place.iconCentre(topInset: WatchMetrics.shared.topInset) * 2)
                .ignoresSafeArea(edges: .top)
                .animation(.easeInOut(duration: ActivityStatus.moveTime), value: place)
        }
    }
}

// Where the clock is on a page: pages with buttons on both sides say so; the root keeps the one from the tab in front.
struct ClockPlaceKey: PreferenceKey {
    static let defaultValue: ActivityPlace? = nil
    static func reduce(value: inout ActivityPlace?, nextValue: () -> ActivityPlace?) { value = value ?? nextValue() }
}

extension View {
    func clockPlace(_ place: ActivityPlace) -> some View { preference(key: ClockPlaceKey.self, value: place) }
    // Only the tab in front reports its clock.
    func inFront(_ front: Bool) -> some View { transformPreference(ClockPlaceKey.self) { if !front { $0 = nil } } }
}

enum ActivityPlace {
    case underCentredClock, underClockOnRight, sheet

    // The icon's centre, from the screen's top.
    // - Clock centred (Playback, Home: buttons on both sides): under the clock, its bottom where the page's content
    //   starts (on Playback, the line of its top buttons' bottom).
    // - Clock on the right (library and pushed pages, login) and sheets: in the middle of the clock's row. Under the
    //   clock is where watchOS puts a scrolled page's small title, and on sheets the sheet's title; beside the clock,
    //   on sheets, watchOS shows its own "iPhone disconnected" icon.
    func iconCentre(topInset: CGFloat) -> CGFloat {
        switch self {
        case .underCentredClock: topInset - ActivityStatus.liftAboveContent - ActivityStatus.iconSize / 2
        case .underClockOnRight, .sheet: ActivityStatus.clockRowCentre(topInset: topInset)
        }
    }
}

struct PhoneActivityIndicator: View {
    private var activity = PhoneActivity.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch activity.state {
            case .idle:
                EmptyView()
            case .waiting:
                // Finamp's fixed blue, not the accent: an orange accent would look like the failed sign.
                // Turns only while shown, and stops at once when Reduce Motion is switched on.
                TimelineView(.animation(paused: reduceMotion)) { context in
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Color.jellyfinBlue)
                        .rotationEffect(.degrees(reduceMotion ? 0 : Self.angle(at: context.date)))
                }
                .accessibilityLabel("Waiting for your iPhone")
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Couldn't reach your iPhone")
            case .reconnecting, .reconnected:
                // One symbol view for both, so the iPhone turns into the tick. An iPhone fading in and out: the watch
                // is trying to reach it (yalit, 27 Nov 2026, in place of the striped waves); a ticked circle: it did.
                // Finamp's blue, as the waiting arrows.
                let done = activity.state == .reconnected
                Image(systemName: done ? "checkmark.circle" : "iphone")
                    .symbolEffect(.pulse, options: .repeating, isActive: !done && !reduceMotion)
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(Color.jellyfinBlue)
                    .accessibilityLabel(done ? "Your iPhone answers again" : "Reconnecting to your iPhone")
            }
        }
        .font(.system(size: ActivityStatus.iconSize, weight: .semibold))
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: ActivityStatus.fadeTime), value: activity.state)
    }

    private static func angle(at date: Date) -> Double {
        let turn = ActivityStatus.turnTime
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: turn) / turn * 360
    }
}

struct LoggedOutView: View {
    var body: some View {
        VStack(spacing: StatusPages.spacing) {
            FinampLogoTile(size: StatusPages.logoSize)
            Text("Connect to Jellyfin")
                .font(.headline)
                .foregroundStyle(Color.fgPrimary)
            Text("Log in to your server in Finamp on your iPhone.")
                .font(.footnote)
                .foregroundStyle(Color.fgSecondary)
                .multilineTextAlignment(.center)
        }
        .scenePadding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

#Preview {
    ContentView()
}
