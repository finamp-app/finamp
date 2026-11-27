import Foundation

// Every wait, timeout and retry between the watch and the phone, in one place; the code that waits reads its value
// from here, with the reason for its value.
//
// The phone has values that must fit these (`lib/services/watch_helper.dart`): it answers a cover request within 2 s
// with the covers it has (`_watchCoverAnswerAfter`; the rest come back as "ask again"), each cover gets at most 10 s
// (`_watchCoverLimit`), both well before `Reply.normal` (30 s) gives up; and it gathers now-playing changes for 150 ms
// before pushing.
enum ConnectionPolicy {
    // MARK: Waiting for the phone to be in reach, before a request is sent

    // Time the app runs (`awake`): a page or cover asked for just before the wrist went down still loads when it's
    // raised. Real time (`clock`): a command must not reach the phone long after it was given.
    enum Patience {
        case awake(Duration)
        case clock(Duration)
    }

    // How long each kind of request waits, and whether it shows the status under the clock (`PhoneActivity`).
    // Covers and the now-playing refresh repeat on their own, and the favourites count only fills in a number, so they
    // wait briefly and stay quiet.
    // While waiting, reachability is checked this often. Time the app runs is counted in steps of at most this much,
    // so a gap longer than a step (the app suspended, wrist down) doesn't count as waiting.
    static let reachabilityPoll: Duration = .milliseconds(100)
    static let maxAwakeStep: Duration = .milliseconds(500)

    static func patience(_ method: String) -> (wait: Patience, shown: Bool) {
        switch method {
        case "artworks", "nowPlaying", "favoritesCount": (.awake(.seconds(5)), false)
        // `sendVolumes` waits and shows the status itself (`Volume`).
        case "setVolume": (.awake(.zero), false)
        // Playback opens the album page with what it has if this doesn't answer soon.
        case "item": (.awake(.seconds(5)), true)
        // Pages give up only when about 30 s have really passed.
        case "list", "home", "search", "artistInfo", "downloadState", "queue", "output", "settings", "playlistMenu":
            (.awake(.seconds(30)), true)
        // Commands are sent once, never repeated: a repeated toggle undoes itself, a repeated skip skips twice.
        default: (.clock(.seconds(3)), true)
        }
    }

    // MARK: Waiting for the answer, once sent

    enum Reply {
        // Transport controls answer at once (0.1-0.9 s on the devices, 2-3 s when the watch wakes Finamp), but a burst
        // of quick skips queues their answers, so they get long enough that the status doesn't turn orange while the
        // phone keeps up.
        static let quickMethods: Set<String> = ["control", "seek"]
        static let quick: Duration = .seconds(10)
        // Starting playback, downloads and settings can take longer on the phone.
        static let normal: Duration = .seconds(30)

        static func timeout(for method: String) -> Duration { quickMethods.contains(method) ? quick : normal }
    }

    // MARK: Volume: retried until the phone confirms it

    enum Volume {
        // After a send that failed (out of reach, a WatchConnectivity error, a refusal), the next one goes this long
        // after it began, or as soon as the phone is back in reach.
        static let retryAfterError: Duration = .seconds(1)
        // A send waits this long for its answer before the phone is asked for its volume: requests take 0.1-0.6 s, a
        // phone waking Finamp in the background up to 3 s.
        static let noAnswerAfter: Duration = .seconds(3)
        // Nothing confirmed this long after the newest crown turn: give up and show the phone's last known volume
        // (long enough not to give up while the crown is still being turned).
        static let giveUpAfter: Duration = .seconds(30)
        // Just after the phone accepted a change, a different volume it pushes may be an older one on its way: the
        // phone is asked for its volume instead.
        static let olderPushWindow: TimeInterval = 1.5
    }

    // MARK: The status under the clock (`PhoneActivity`)

    enum Status {
        // Requests take 0.1-0.6 s on the devices; the arrows show only for one still waiting after this.
        static let showAfter: Duration = .seconds(1)
        // How long the orange sign stays, unless a request gets through first.
        static let failedFor: Duration = .seconds(4)
        // How long the ticked circle stays once a phone that wasn't answering (`Health`) answers again: as long as the
        // orange sign, so it can be read at a glance.
        static let reconnectedFor: Duration = .seconds(4)
    }

    // MARK: Covers

    enum Cover {
        // Covers come only through the phone; the watch never uses its own internet connection.
        // Playback asks again for a cover whose load ended empty: when the wrist is raised (this soon after the last
        // try at the earliest), then at most this often while it's on screen.
        static let retryOnWake: TimeInterval = 2
        static let retryEvery: TimeInterval = 10
        // Rows that appear together join one request.
        static let batchDelay: Duration = .milliseconds(30)
    }

    // MARK: A connection stuck on "not reachable"

    enum Recovery {
        // A request has waited this long, with the app on screen, for the phone to come in reach: the watch restarts
        // its own connection (`activate()` again), once until the phone is reachable again. Only the watch acts; nothing
        // is sent to the phone, so Finamp on the iPhone is never made to do anything. Normally the phone is reachable
        // 0.1-0.4 s after the app comes on screen.
        static let restartAfter: Duration = .seconds(5)
    }

    // MARK: A connection that is in reach and answers nothing

    enum Health {
        // The app on screen, the phone in reach, a request sent, and nothing at all received since (no answer, no
        // live update, no context): after this long the watch asks the one thing the phone answers without its server
        // (`nowPlaying`). No answer to that within `probeAnswer`, still in reach: the connection counts as not
        // answering. Answers take 0.1-0.7 s on the devices; a page waiting on a slow server can take longer, which is
        // why this basic request decides and not the page's own.
        // Both short enough that a tap with no answer is known within 10 s, the usual limit for keeping a user's
        // attention on a wait (Nielsen's response-time limits: 0.1 s, 1 s, 10 s), and each over four times the
        // slowest basic answer seen on the devices (0.7 s). A page still loading from a slow server only costs one
        // extra basic request, which answers without the server.
        static let probeAfter: Duration = .seconds(3)
        static let probeAnswer: Duration = .seconds(3)
        // After a phone call ended (the watch's call observer) the basic request goes out this soon: on 26 Nov 2026
        // the connection stopped answering right after calls, most reliably after calls taken on the watch.
        static let probeAfterCall: Duration = .seconds(1)
        // While not answering and on screen: the basic request again this often, to notice the end.
        static let probeEvery: Duration = .seconds(10)
        // The last resort (yalit, 27 Nov 2026: "maybe a minnute of orange sign first? 2-3 connection reattepts?"):
        // the session is activated again when the state begins and after every second unanswered basic request, three
        // times in all; after `closeAfterUnanswered` unanswered ones (about a minute on screen) the app says so for
        // `closingNoticeFor` and closes itself. Leaving the front is what ended this state on the devices (26 Nov
        // 15:13:46 and 21:13:07); an app can leave only by closing, and cannot open itself again. A fresh start
        // answered within 4 s on 27 Nov 05:34:21. Three unanswered checks count as a dead link, the usual
        // keep-alive convention (three missed probes); the wrist going down closes it sooner, without a notice
        // (`PhoneConnection.closeWhileOffScreen`).
        static let reconnectAttempts = 3
        static let closeAfterUnanswered = 3
        static let closingNoticeFor: Duration = .seconds(3)
    }

    // MARK: Playback

    enum Playback {
        // Pushes are the normal path; with none for this long while Playback is on screen, it asks for now playing.
        static let refreshEvery: TimeInterval = 10
    }
}
