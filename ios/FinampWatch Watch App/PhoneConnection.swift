import CallKit
import Foundation
import WatchConnectivity

struct LibraryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    // Image ID plus tag; empty when there is no cover.
    let artworkKey: String
    // Destination type in mixed lists.
    var kind = ""
    // Seconds; zero means unknown.
    var duration: Double = 0
    // Zero means unknown.
    var year = 0
    // Finamp's formatted release date (its Release Date Format setting); empty when unknown.
    var releaseDate = ""
    // Album or playlist total; zero means unknown.
    var trackCount = 0
    var blurHash = ""
    // Album artist for albums, first artist for tracks.
    var artistID = ""
    var favorite = false
    // Includes queued downloads.
    var downloaded = false
    // Dependency explanation; nil when unlocked.
    var downloadLock: String?
    // Album artists with photos; empty for other item types.
    var artists: [LibraryItem] = []

    static func artists(from value: Any?) -> [LibraryItem] {
        ((value as? [[String: Any]]) ?? []).map { artist in
            let id = artist["id"] as? String ?? ""
            return LibraryItem(
                id: id,
                name: artist["name"] as? String ?? "",
                subtitle: "",
                artworkKey: id.isEmpty ? "" : "artist-\(id)"
            )
        }
    }
}

struct HomeSections {
    let recent: [LibraryItem]
    let newAlbums: [LibraryItem]
    let actions: [QuickAction]
}

struct QuickAction: Identifiable, Hashable {
    let index: Int
    let title: String
    let action: String

    var id: Int { index }

    // Used for Home's first frame before the phone replies.
    static var cached: [QuickAction]? {
        get {
            guard let rows = UserDefaults.standard.array(forKey: "quickActions") as? [[String: Any]] else { return nil }
            return rows.compactMap(decode)
        }
        set {
            let rows = newValue?.map { ["index": $0.index, "title": $0.title, "action": $0.action] as [String: Any] }
            UserDefaults.standard.set(rows, forKey: "quickActions")
        }
    }

    static func decode(_ row: [String: Any]) -> QuickAction? {
        guard let index = row["index"] as? Int else { return nil }
        return QuickAction(index: index, title: row["title"] as? String ?? "", action: row["action"] as? String ?? "")
    }

    var systemImage: String {
        switch action {
        case "shuffleTracks": return "shuffle"
        case "playRandomItem": return "dice"
        case "playRandomFavoriteItem": return "heart.circle"
        case "playPreviousQueue": return "clock.arrow.circlepath"
        case "surpriseMe": return "sparkles"
        default: return "play"
        }
    }
}

struct SearchResults {
    let artists: [LibraryItem]
    // Artists credited only on tracks, not as album artists (Finamp's Performing Artists tab).
    let performingArtists: [LibraryItem]
    let albums: [LibraryItem]
    let playlists: [LibraryItem]
    let tracks: [LibraryItem]

    var isEmpty: Bool { artists.isEmpty && performingArtists.isEmpty && albums.isEmpty && playlists.isEmpty && tracks.isEmpty }
}

enum DownloadReply {
    case downloading
    case alreadyDownloaded
    case ask(DownloadQuestion)
}

struct ArtistInfo {
    let tracks: Int
    let albums: Int
    let favorite: Bool
    let downloaded: Bool
    let downloadLock: String?
    // The order of the artist page's album sections ("albums", "appearsOn"), from Finamp's artist screen setting.
    let sections: [String]
}

struct ReloadQuestion {
    let text: String
    let button: String
    // Preserve the old queue when reloading.
    let archive: Bool
}

enum DownloadQuestion {
    case transcode(transcodedLabel: String)
    case location([DownloadLocationChoice])
    case confirm(message: String)
}

struct DownloadLocationChoice: Hashable {
    let id: String
    let name: String
}

enum PhoneError: LocalizedError {
    case notReachable
    case phone(String)
    case serverUnreachable
    case noAnswer
    case unexpectedReply
    // A command not sent: the phone wasn't in reach within its time, and sent later it would surprise.
    case expired
    // A command not sent: the phone is in reach and answers nothing (`ConnectionPolicy.Health`). Sent anyway it may be
    // carried out without the watch ever learning it, so a second tap undoes the first (seen 26 Nov 2026).
    case notAnswering

    var errorDescription: String? {
        switch self {
        case .notReachable: return String(localized: "Can't reach your iPhone")
        case .serverUnreachable: return String(localized: "Can't reach your Jellyfin server")
        case .noAnswer: return String(localized: "Your iPhone didn't answer")
        case .phone(let message): return message
        case .unexpectedReply: return String(localized: "Unexpected reply from your iPhone")
        case .expired: return String(localized: "Not sent: your iPhone wasn't in reach in time")
        // Never shown: like every connection failure it is only the sign under the clock (`PhoneMessage.show`).
        case .notAnswering: return String(localized: "Your iPhone didn't answer")
        }
    }
}

// The watch holds no Jellyfin token; requests go through the phone.
final class PhoneConnection: NSObject, WCSessionDelegate {
    static let shared = PhoneConnection()

    func activate() {
        let info = Bundle.main.infoDictionary
        WatchLog.info("launch \(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?"))")
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        callObserver.setDelegate(self, queue: .main)
        let stored = WCSession.default.receivedApplicationContext
        WatchLog.fine("context at launch: \(stored.keys.sorted().joined(separator: ", "))")
        apply(stored)
    }

    // Apply the accent before other state so the first frame renders correctly.
    private func apply(_ values: [String: Any]) {
        ThemeStore.shared.applyAccent(values["accent"])
        AccountStore.shared.apply(values["account"])
        if let state = values["nowPlaying"] as? [String: Any] {
            NowPlayingStore.shared.update(from: state)
        }
        if let enabled = values["transcoding"] as? Bool { PhoneSettings.shared.transcoding = enabled }
        if let offline = values["offline"] as? Bool { PhoneSettings.shared.offline = offline }
        if let prefer = values["preferFavorites"] as? Bool { PhoneSettings.shared.preferFavorites = prefer }
        if let volume = values["volume"] as? Double { PhoneVolume.shared.pushed(volume) }
        if let airPlay = values["airPlay"] as? Bool { PhoneVolume.shared.airPlay = airPlay }
        if let route = values["outputRoute"] as? [String: Any] {
            PhoneVolume.shared.route = (route["route"] as? String ?? "", route["routeType"] as? String ?? "")
        }
        if let favorites = values["favoriteStates"] as? [String: Bool] {
            for (id, favorite) in favorites { FavoriteOverrides.shared.phoneReported(id, favorite) }
        }
    }

    // The phone can end pages early for byte limits; only an empty page means the end.
    // `quiet`: a reload the phone caused (not a tap) doesn't show the status under the clock.
    func list(
        _ type: String, parentId: String? = nil, offset: Int = 0, limit: Int = 50, quiet: Bool = false
    ) async throws -> [LibraryItem] {
        var args: [String: Any] = ["type": type, "offset": offset, "limit": limit]
        if let parentId { args["parentId"] = parentId }
        let rows = try await request("list", args, quiet: quiet)["result"]
        guard rows is [[String: Any]] else { throw PhoneError.unexpectedReply }
        return Self.items(from: rows)
    }

    func home(quiet: Bool = false) async throws -> HomeSections {
        guard let sections = try await request("home", [:], quiet: quiet)["result"] as? [String: Any] else { throw PhoneError.unexpectedReply }
        let actions = ((sections["actions"] as? [[String: Any]]) ?? []).compactMap(QuickAction.decode)
        return HomeSections(
            recent: Self.items(from: sections["recent"]),
            newAlbums: Self.items(from: sections["newAlbums"]),
            actions: actions
        )
    }

    func search(_ query: String) async throws -> SearchResults {
        guard let sections = try await request("search", ["query": query])["result"] as? [String: Any] else { throw PhoneError.unexpectedReply }
        return SearchResults(
            artists: Self.items(from: sections["artists"]),
            performingArtists: Self.items(from: sections["performingArtists"]),
            albums: Self.items(from: sections["albums"]),
            playlists: Self.items(from: sections["playlists"]),
            tracks: Self.items(from: sections["tracks"])
        )
    }

    func output() async throws -> (route: String, routeType: String, volume: Double) {
        guard let reply = try await request("output", [:])["result"] as? [String: Any],
              let volume = reply["volume"] as? Double else { throw PhoneError.unexpectedReply }
        // A fresh read of the phone's volume: what the crown goes back to if a change of it fails.
        PhoneVolume.shared.observed(volume)
        return (reply["route"] as? String ?? "", reply["routeType"] as? String ?? "", volume)
    }

    // When the crown's newest value was set (`PhoneVolume.wanted`).
    private var wantedAt = ContinuousClock.now
    private var volumeInFlight = false

    // From a crown turn. One message in flight: sending every crown tick would queue stale values and delay the volume.
    func setVolume(_ volume: Double) {
        PhoneVolume.shared.wanted = volume
        wantedAt = .now
        guard !volumeInFlight else { return }
        volumeInFlight = true
        Task {
            await sendVolumes()
            volumeInFlight = false
        }
    }

    // What one send of a volume came to.
    private enum VolumeTry {
        // The phone answered `true`.
        case accepted
        // It may have arrived: no answer in time, or an answer the watch didn't expect.
        case uncertain
        // The phone answered with an error of its own (e.g. Finamp still starting).
        case refused(String)
        case failed
    }

    // Sends the crown's newest value until the phone confirms it, for up to `ConnectionPolicy.Volume.giveUpAfter` from
    // the newest turn (an exact value: applying it twice changes nothing, and the phone applies requests in the order
    // they arrive, so the last to reach it wins). Confirmed only by the phone's `true` to that send, or by reading the
    // phone's volume when it may have arrived (a slow answer isn't a lost message: a phone waking Finamp takes up to
    // 3 s), never by a pushed volume, which may be old. A newer turn is sent instead of checking an older one. If
    // nothing gets through, the crown shows the phone's last known volume again.
    private func sendVolumes() async {
        let volumes = PhoneVolume.shared
        // The status shows for one send still unanswered after a second, and from the first failure until it's settled;
        // not for a crown that keeps turning while every send is answered.
        var retrying: Int?
        var outcome = PhoneActivity.Outcome.neutral
        var refusal: String?
        defer { if let retrying { PhoneActivity.shared.end(retrying, outcome) } }
        do {
            while let volume = volumes.wanted {
                let deadline = wantedAt + ConnectionPolicy.Volume.giveUpAfter
                guard ContinuousClock.now < deadline else {
                    WatchLog.warning("setVolume: gave up, \(ConnectionPolicy.Volume.giveUpAfter) after the newest turn")
                    if retrying == nil { retrying = PhoneActivity.shared.begin() }
                    volumes.wanted = nil
                    if outcome == .answered, let refusal { PhoneMessage.shared.text = refusal }
                    return
                }
                guard WCSession.default.isReachable else {
                    outcome = .connectionFailed
                    if retrying == nil { retrying = PhoneActivity.shared.begin() }
                    try await waitForPhone(until: min(.now + ConnectionPolicy.Volume.retryAfterError, deadline))
                    continue
                }
                let attempt = PhoneActivity.shared.begin()
                let result: VolumeTry
                do {
                    result = try await sendVolume(volume, before: deadline)
                } catch {
                    PhoneActivity.shared.end(attempt, .neutral)
                    throw error
                }
                if case .accepted = result {
                    PhoneActivity.shared.end(attempt, .answered)
                } else {
                    // A failed try ends quietly; the failure shows only if the whole change gives up.
                    PhoneActivity.shared.end(attempt, .neutral)
                    if retrying == nil { retrying = PhoneActivity.shared.begin() }
                }
                switch result {
                case .accepted:
                    outcome = .answered
                    volumes.observed(volume, accepted: true)
                    if volumes.wanted == volume { volumes.wanted = nil }
                case .uncertain:
                    outcome = .connectionFailed
                    // A newer turn is waiting: send that rather than check this one.
                    guard volumes.wanted == volume else { continue }
                    let check = PhoneActivity.shared.begin()
                    let read: (volume: Double?, answered: Bool)
                    do {
                        read = try await readVolume(before: deadline)
                    } catch {
                        PhoneActivity.shared.end(check, .neutral)
                        throw error
                    }
                    PhoneActivity.shared.end(check, read.answered ? .answered : .neutral)
                    if read.answered { outcome = .answered }
                    if let actual = read.volume {
                        volumes.observed(actual)
                        if abs(actual - volume) < 0.005, volumes.wanted == volume { volumes.wanted = nil }
                    }
                case .refused(let message):
                    outcome = .answered
                    refusal = message
                    try await waitForPhone(until: min(.now + ConnectionPolicy.Volume.retryAfterError, deadline))
                case .failed:
                    outcome = .connectionFailed
                    try await waitForPhone(until: min(.now + ConnectionPolicy.Volume.retryAfterError, deadline))
                }
            }
        } catch {
            // Cancelled: no verdict on the connection; the crown shows the phone's volume again.
            volumes.wanted = nil
            outcome = .neutral
        }
    }

    // One send of `volume`, handed to WatchConnectivity only before `deadline`.
    private func sendVolume(_ volume: Double, before deadline: ContinuousClock.Instant) async throws -> VolumeTry {
        let left = deadline - .now
        do {
            let reply = try await request("setVolume", ["volume": volume], replyTimeout: min(ConnectionPolicy.Volume.noAnswerAfter, left),
                                          quiet: true, patience: .clock(left))
            return reply["result"] as? Bool == true ? .accepted : .uncertain
        } catch is CancellationError {
            throw CancellationError()
        } catch PhoneError.phone(let message) {
            return .refused(message)
        } catch {
            return Self.mayHaveArrived(error) ? .uncertain : .failed
        }
    }

    // After a pushed volume that may be an older one still on its way (`PhoneVolume.pushed`): the phone's volume now,
    // read quietly; not taken if the crown turned meanwhile, since that change's answer brings the volume.
    func recheckVolume() async {
        let turnedAt = wantedAt
        guard let read = try? await readVolume(before: .now + ConnectionPolicy.Volume.noAnswerAfter),
              let volume = read.volume, wantedAt == turnedAt else { return }
        PhoneVolume.shared.observed(volume)
    }

    // The phone's volume read now (the Output sheet's request), before `deadline`. `answered`: the phone replied,
    // even if with an error.
    private func readVolume(before deadline: ContinuousClock.Instant) async throws -> (volume: Double?, answered: Bool) {
        let left = deadline - .now
        guard left > .zero else { return (nil, false) }
        do {
            let reply = try await request("output", [:], replyTimeout: min(ConnectionPolicy.Volume.noAnswerAfter, left),
                                          quiet: true, patience: .clock(left))
            guard let volume = (reply["result"] as? [String: Any])?["volume"] as? Double else { return (nil, true) }
            return (volume, true)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return (nil, Self.outcome(of: error) == .answered)
        }
    }

    // Errors after which the message may still have reached the phone.
    private static func mayHaveArrived(_ error: Error) -> Bool {
        switch error {
        case PhoneError.noAnswer, PhoneError.unexpectedReply: true
        case let error as WCError: error.code == .messageReplyTimedOut || error.code == .messageReplyFailed
        default: false
        }
    }

    // Until `until`, or as soon as the phone comes back in reach (if it was out of reach).
    private func waitForPhone(until: ContinuousClock.Instant) async throws {
        let wasReachable = WCSession.default.isReachable
        while ContinuousClock.now < until {
            if !wasReachable && WCSession.default.isReachable { return }
            try await Task.sleep(until: min(ContinuousClock.now + ConnectionPolicy.reachabilityPoll, until), clock: .continuous)
            if !WCSession.default.isReachable { await noteWaitingForPhone() }
        }
    }

    // A connection stuck on "not reachable" (`ConnectionPolicy.Recovery`): how long requests have waited for the phone,
    // in the app's running time, since it was last reachable, and whether the connection was already restarted.
    @MainActor private var stuckFor = Duration.zero
    @MainActor private var stuckLastNoted: ContinuousClock.Instant?
    @MainActor private var restartedWhileStuck = false

    // Called by every loop that waits for the phone to come in reach.
    @MainActor private func noteWaitingForPhone() {
        // Only time on screen counts: off screen (wrist down, or woken in the background by an update from the
        // phone) "not reachable" is the normal state, and on 26 Nov 2026 the restart fired there three times.
        guard scene == "active" else {
            stuckLastNoted = nil
            return
        }
        let now = ContinuousClock.now
        // As in `request`: a long gap is the app suspended (wrist down), not time spent waiting on screen.
        if let last = stuckLastNoted { stuckFor += min(now - last, ConnectionPolicy.maxAwakeStep) }
        stuckLastNoted = now
        guard !restartedWhileStuck, stuckFor >= ConnectionPolicy.Recovery.restartAfter, WCSession.isSupported() else {
            return
        }
        restartedWhileStuck = true
        let session = WCSession.default
        WatchLog.warning("connection: not reachable for \(stuckFor.ms) ms of waiting; restarting it (\(Self.describe(session)))")
        session.delegate = self
        session.activate()
    }

    // For the log: "in reach, but nothing answers" (26 Nov 2026: 43 requests in two minutes failed while the session
    // said reachable, and only single lines showed it). Logged at the 3rd in a row, then every 10th, with when the
    // phone was last heard on each path; and once when answers come back.
    @MainActor private var unanswered = 0
    @MainActor private var unansweredSince: Date?
    @MainActor private var lastAnswer: Date?
    @MainActor private var lastLiveUpdate: Date?
    @MainActor private var lastContext: Date?

    @MainActor private func noteUnanswered(_ session: WCSession) {
        if unanswered == 0 { unansweredSince = Date() }
        unanswered += 1
        guard unanswered == 3 || unanswered % 10 == 0 else { return }
        func ago(_ date: Date?) -> String { date.map { "\(Int(-$0.timeIntervalSinceNow)) s ago" } ?? "not since launch" }
        WatchLog.warning("connection: in reach, but \(unanswered) requests in a row got no answer, for \(Int(-(unansweredSince ?? Date()).timeIntervalSinceNow)) s (last answer \(ago(lastAnswer)), last live update \(ago(lastLiveUpdate)), last context \(ago(lastContext)); \(Self.describe(session)))")
    }

    @MainActor private func noteAnswered() {
        if unanswered >= 3, let since = unansweredSince {
            WatchLog.info("connection: answers again after \(unanswered) unanswered requests in \(Int(-since.timeIntervalSinceNow)) s")
        }
        unanswered = 0
        unansweredSince = nil
        lastAnswer = Date()
        noteReceived()
    }

    // MARK: In reach, but not answering (`ConnectionPolicy.Health`)

    // When the oldest request was sent since anything last arrived from the phone; nil while nothing is waiting.
    @MainActor private var silentSince: ContinuousClock.Instant?
    @MainActor private var received = 0
    @MainActor private var notAnswering = false
    @MainActor private var notAnsweringSince: Date?
    @MainActor private var probing = false
    @MainActor private var probeWhenReached = false
    private let callObserver = CXCallObserver()

    // A request is about to be handed to WatchConnectivity.
    @MainActor private func noteSent() {
        guard silentSince == nil else { return }
        let since = ContinuousClock.now
        silentSince = since
        Task { @MainActor in
            try? await Task.sleep(for: ConnectionPolicy.Health.probeAfter)
            guard silentSince == since else { return }
            await probe("nothing received for \((ContinuousClock.now - since).ms) ms")
        }
    }

    // Anything arrived from the phone: an answer, a live update, a context.
    @MainActor private func noteReceived() {
        silentSince = nil
        received += 1
        guard notAnswering else { return }
        notAnswering = false
        PhoneActivity.shared.setNotAnswering(false)
        WatchLog.info("connection: the iPhone answers again, after \(Int(-(notAnsweringSince ?? Date()).timeIntervalSinceNow)) s of not answering")
        notAnsweringSince = nil
        // Pages that failed meanwhile load again, as when the phone comes back in reach.
        NotificationCenter.default.post(name: .phoneBecameReachable, object: nil)
    }

    // Off screen or out of reach nothing is expected to arrive: that time doesn't count.
    @MainActor private func stopCountingSilence() { silentSince = nil }

    private enum Probe { case answered, unanswered, notSent }

    // The basic request: `nowPlaying`, which the phone answers at once without its server.
    @discardableResult
    @MainActor private func probe(_ reason: String) async -> Probe {
        let session = WCSession.default
        guard !probing, scene == "active", session.activationState == .activated, session.isReachable else { return .notSent }
        probing = true
        defer { probing = false }
        let before = received
        do {
            let reply = try await request(
                "nowPlaying", [:], replyTimeout: ConnectionPolicy.Health.probeAnswer, quiet: true,
                patience: .clock(.seconds(1)), probe: true)
            if let state = reply["result"] as? [String: Any] { NowPlayingStore.shared.update(from: state) }
            return .answered
        } catch {
            // Only a basic request that went out and got nothing back counts.
            if case PhoneError.expired = error { return .notSent }
            guard Self.outcome(of: error) == .connectionFailed, received == before, scene == "active", session.isReachable
            else { return .notSent }
            guard !notAnswering else {
                unansweredChecks += 1
                return .unanswered
            }
            notAnswering = true
            notAnsweringSince = Date()
            unansweredChecks = 0
            PhoneActivity.shared.setNotAnswering(true)
            func ago(_ date: Date?) -> String { date.map { "\(Int(-$0.timeIntervalSinceNow)) s ago" } ?? "not since launch" }
            WatchLog.warning("connection: the iPhone is in reach and not answering (\(reason); the basic request got no answer in \(ConnectionPolicy.Health.probeAnswer.ms) ms; last answer \(ago(lastAnswer)), last live update \(ago(lastLiveUpdate)), last context \(ago(lastContext)); \(Self.describe(session)))")
            Task { @MainActor in await recover() }
            return .unanswered
        }
    }

    // Recovery while not answering. What is known to end it is a fresh status update from the watch to the iPhone
    // (Finamp leaving the front and returning; a notification), which an app can't send; so the session is activated
    // again (decision 70's restart, here for "in reach, no answers"), the basic request keeps asking, and a command
    // tapped meanwhile is held back (`holdBack`). The user is told nothing beyond the sign under the clock (yalit,
    // 27 Nov 2026: no instruction on screen).
    @MainActor private func recover() async {
        let session = WCSession.default
        var attempts = 0
        func activateAgain() {
            attempts += 1
            WatchLog.info("connection: recovery: activating the session again (\(attempts) of \(ConnectionPolicy.Health.reconnectAttempts))")
            session.delegate = self
            session.activate()
        }
        activateAgain()
        while notAnswering {
            try? await Task.sleep(for: ConnectionPolicy.Health.probeEvery)
            guard notAnswering else { break }
            // Only a basic request that went out and came back empty counts: not time off screen or out of reach.
            // Every such request counts, not only this loop's own (27 Nov 2026 05:35-05:39: with the wrist raised
            // for a few seconds at a time, this loop's checks were all skipped, off screen or behind another check,
            // and the app never got past the first restart in four minutes).
            await probe("still not answering")
            guard notAnswering, scene == "active" else { continue }
            if unansweredChecks >= ConnectionPolicy.Health.closeAfterUnanswered {
                await closeAsLastResort(unansweredChecks, attempts: attempts)
                return
            }
            if attempts < min(1 + unansweredChecks / 2, ConnectionPolicy.Health.reconnectAttempts) { activateAgain() }
        }
    }

    // Basic requests unanswered since the state began, whoever sent them.
    @MainActor private var unansweredChecks = 0

    // Nothing brought the phone back: say so, and close. Anything arriving during the notice calls it off.
    @MainActor private func closeAsLastResort(_ unanswered: Int, attempts: Int) async {
        let notice = String(localized: "Couldn't reach your iPhone. Closing Finamp.")
        WatchLog.warning("connection: last resort: closing the app (not answering for \(Int(-(notAnsweringSince ?? Date()).timeIntervalSinceNow)) s, \(unanswered) basic requests unanswered, the session activated again \(attempts) times)")
        PhoneMessage.shared.text = notice
        WatchLog.shared.flush()
        try? await Task.sleep(for: ConnectionPolicy.Health.closingNoticeFor)
        guard notAnswering else {
            if PhoneMessage.shared.text == notice { PhoneMessage.shared.text = nil }
            WatchLog.info("connection: last resort called off, the iPhone answered")
            return
        }
        exit(0)
    }

    // A command while the phone isn't answering: not sent; the sign under the clock is all that shows.
    @MainActor private func holdBack(_ method: String) -> Bool {
        guard notAnswering else { return false }
        WatchLog.fine("\(method): held back, the iPhone isn't answering")
        return true
    }

    @MainActor private func callEnded() {
        Task { @MainActor in
            try? await Task.sleep(for: ConnectionPolicy.Health.probeAfterCall)
            if scene == "active", WCSession.default.isReachable {
                await probe("a phone call just ended")
            } else {
                probeWhenReached = true
            }
        }
    }

    @MainActor private func phoneReachedAgain() {
        if restartedWhileStuck {
            WatchLog.info("connection: reachable again \(stuckFor.ms) ms after it got stuck")
        }
        stuckFor = .zero
        stuckLastNoted = nil
        restartedWhileStuck = false
        // Back in reach after a call, or while the phone wasn't answering: ask at once.
        if probeWhenReached || notAnswering {
            let reason = probeWhenReached ? "a phone call ended while the app was off screen" : "in reach again while not answering"
            probeWhenReached = false
            Task { @MainActor in await probe(reason) }
        }
    }

    // The phone checks the action name against its current index after reordering.
    func runQuickAction(_ index: Int, action: String) async throws {
        _ = try await request("quickAction", ["index": index, "action": action])
    }

    func shuffleAll() async throws {
        _ = try await request("shuffleAll", [:])
    }

    func refreshNowPlaying() async throws {
        if let state = try await request("nowPlaying", [:])["result"] as? [String: Any] {
            NowPlayingStore.shared.update(from: state)
        }
    }

    func control(_ action: String) async throws {
        _ = try await request("control", ["action": action])
    }

    // The phone drops it if `queueEntry` is no longer playing.
    func seek(to position: Double, in queueEntry: String) async throws {
        _ = try await request("seek", ["position": position, "queueEntryId": queueEntry])
    }

    func queue(quiet: Bool = false) async throws -> [LibraryItem] {
        Self.items(from: try await request("queue", [:], quiet: quiet)["result"])
    }

    // Return the phone's authoritative state for optimistic UI updates.
    func setFavorite(_ id: String, _ favorite: Bool) async throws -> Bool {
        guard let result = try await request("favorite", ["id": id, "favorite": favorite])["result"] as? Bool else {
            throw PhoneError.unexpectedReply
        }
        return result
    }

    // Send download request, repeating with answers as needed.
    func download(_ id: String, answers: [String: Any] = [:]) async throws -> DownloadReply {
        let reply = try await request("download", answers.merging(["id": id]) { _, new in new })["result"]
            as? [String: Any] ?? [:]
        switch reply["ask"] as? String {
        case "transcode":
            return .ask(.transcode(transcodedLabel: reply["transcodedLabel"] as? String ?? String(localized: "Transcoded")))
        case "location":
            let locations = ((reply["locations"] as? [[String: Any]]) ?? []).compactMap { row -> DownloadLocationChoice? in
                guard let id = row["id"] as? String else { return nil }
                return DownloadLocationChoice(id: id, name: row["name"] as? String ?? id)
            }
            return .ask(.location(locations))
        case "confirm":
            return .ask(.confirm(message: reply["message"] as? String ?? String(localized: "Download?")))
        default:
            switch reply["status"] as? String {
            case "alreadyDownloaded": return .alreadyDownloaded
            case "downloading": return .downloading
            default: throw PhoneError.unexpectedReply
            }
        }
    }

    // False means queued until the phone is foregrounded, for up to two minutes.
    func showOutputPicker() async throws -> Bool {
        try await request("showOutputPicker", [:])["result"] as? String == "shown"
    }

    func settings() async throws -> (transcoding: Bool, offline: Bool) {
        guard let result = try await request("settings", [:])["result"] as? [String: Any] else {
            throw PhoneError.unexpectedReply
        }
        return (result["transcoding"] as? Bool ?? false, result["offline"] as? Bool ?? false)
    }

    func setSetting(_ name: String, _ enabled: Bool) async throws -> ReloadQuestion? {
        let reply = try await request("setSetting", ["name": name, "enabled": enabled])["result"] as? [String: Any]
        guard let question = reply?["reload"] as? String else { return nil }
        return ReloadQuestion(
            text: question,
            button: reply?["reloadButton"] as? String ?? "",
            archive: reply?["archive"] as? Bool ?? false
        )
    }

    func reloadQueue(archive: Bool) async throws {
        _ = try await request("reloadQueue", ["archive": archive])
    }

    func artistInfo(_ id: String) async throws -> ArtistInfo {
        guard let reply = try await request("artistInfo", ["id": id])["result"] as? [String: Any] else { throw PhoneError.unexpectedReply }
        if let favorite = reply["favorite"] as? Bool {
            FavoriteOverrides.shared.phoneReported(id, favorite)
        }
        return ArtistInfo(
            tracks: reply["tracks"] as? Int ?? 0,
            albums: reply["albums"] as? Int ?? 0,
            favorite: reply["favorite"] as? Bool ?? false,
            downloaded: reply["downloaded"] as? Bool ?? false,
            downloadLock: reply["downloadLock"] as? String,
            sections: reply["sections"] as? [String] ?? ["albums", "appearsOn"]
        )
    }

    // Finamp's playlist menu for a track: its heart, every playlist, and which of them is known to hold it.
    // `color`: the track's cover colour (ARGB), which Finamp themes the menu with.
    func playlistMenu(_ id: String) async throws
        -> (favorite: Bool, playlists: [LibraryItem], included: Set<String>, color: Int?) {
        guard let reply = try await request("playlistMenu", ["id": id])["result"] as? [String: Any] else {
            throw PhoneError.unexpectedReply
        }
        let rows = reply["playlists"] as? [[String: Any]] ?? []
        let included = Set(rows.filter { $0["included"] as? Bool == true }.compactMap { $0["id"] as? String })
        let color = (reply["color"] as? NSNumber)?.intValue
        return (reply["favorite"] as? Bool ?? false, Self.items(from: rows), included, color)
    }

    // Adds the track to a playlist or takes it out; answers whether the playlist now holds it.
    func playlistToggle(_ id: String, playlistId: String, add: Bool) async throws -> Bool {
        guard let result = try await request("playlistToggle", ["id": id, "playlistId": playlistId, "add": add])["result"]
            as? Bool else { throw PhoneError.unexpectedReply }
        return result
    }

    // Deletes a download from the phone; answers Finamp's message, nil if it wasn't downloaded.
    func deleteDownload(_ id: String) async throws -> String? {
        let reply = try await request("deleteDownload", ["id": id])["result"] as? [String: Any] ?? [:]
        return reply["message"] as? String
    }

    func downloadState(_ id: String) async throws -> (downloaded: Bool, lock: String?) {
        guard let reply = try await request("downloadState", ["id": id])["result"] as? [String: Any] else { throw PhoneError.unexpectedReply }
        return (reply["downloaded"] as? Bool ?? false, reply["downloadLock"] as? String)
    }

    // Favourite Tracks loads in pages; this is the whole list's length.
    func favoritesCount() async throws -> Int {
        guard let count = try await request("favoritesCount", [:])["result"] as? Int else { throw PhoneError.unexpectedReply }
        return count
    }

    func skipTo(id: String) async throws {
        _ = try await request("control", ["action": "skipTo", "id": id])
    }

    func play(
        _ type: String,
        parentId: String? = nil,
        startId: String? = nil,
        shuffle: Bool = false,
        extra: [String: Any] = [:]
    ) async throws {
        var args: [String: Any] = extra.merging(["type": type, "shuffle": shuffle]) { _, new in new }
        if let parentId { args["parentId"] = parentId }
        if let startId { args["startId"] = startId }
        _ = try await request("play", args)
    }

    // One item's row, e.g. the playing track's album before Playback opens its page.
    func item(_ id: String) async throws -> LibraryItem {
        let reply = try await request("item", ["id": id])
        guard let item = Self.items(from: [reply["result"]].compactMap { $0 }).first else { throw PhoneError.unexpectedReply }
        return item
    }

    private static func items(from rows: Any?) -> [LibraryItem] {
        ((rows as? [[String: Any]]) ?? []).compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            if let favorite = row["favorite"] as? Bool {
                FavoriteOverrides.shared.phoneReported(id, favorite)
            }
            return LibraryItem(
                id: id,
                name: row["name"] as? String ?? "",
                subtitle: row["subtitle"] as? String ?? "",
                artworkKey: row["artworkKey"] as? String ?? "",
                kind: row["kind"] as? String ?? "",
                duration: row["duration"] as? Double ?? 0,
                year: row["year"] as? Int ?? 0,
                releaseDate: row["releaseDate"] as? String ?? "",
                trackCount: row["trackCount"] as? Int ?? 0,
                blurHash: row["blurHash"] as? String ?? "",
                artistID: row["artistId"] as? String ?? "",
                favorite: row["favorite"] as? Bool ?? false,
                downloaded: row["downloaded"] as? Bool ?? false,
                downloadLock: row["downloadLock"] as? String,
                artists: LibraryItem.artists(from: row["artists"])
            )
        }
    }

    func playTracks(index: Int, startId: String) async throws {
        _ = try await request("play", ["type": "tracks", "index": index, "startId": startId])
    }

    // Keys are <id>-<size>; absent from both covers and missing means retry.
    func artworks(_ requests: [(id: String, size: Int)]) async throws -> (covers: [String: Data], missing: Set<String>) {
        let reply = try await request("artworks", ["items": requests.map { ["id": $0.id, "size": $0.size] }])
        return (reply["artworks"] as? [String: Data] ?? [:], Set(reply["missing"] as? [String] ?? []))
    }

    // Every wait and timeout here comes from `ConnectionPolicy`.
    private func request(
        _ method: String, _ args: [String: Any], replyTimeout: Duration? = nil, quiet: Bool = false,
        patience override: ConnectionPolicy.Patience? = nil, probe: Bool = false
    ) async throws -> [String: Any] {
        let replyTimeout = replyTimeout ?? ConnectionPolicy.Reply.timeout(for: method)
        let session = WCSession.default
        let (byKind, shown) = ConnectionPolicy.patience(method)
        let patience = override ?? byKind
        let token = shown && !quiet ? PhoneActivity.shared.begin() : nil
        var outcome = PhoneActivity.Outcome.neutral
        defer {
            // Any reply shows the connection works, shown request or not.
            if outcome == .answered { PhoneActivity.shared.answered() }
            if let token { PhoneActivity.shared.end(token, outcome) }
        }
        // Commands (the ones that wait by the clock) are held back while the phone isn't answering.
        if case .clock = patience, !probe, await holdBack(method) {
            outcome = .connectionFailed
            throw PhoneError.notAnswering
        }
        let start = ContinuousClock.now
        // A command carries its deadline to the moment it's handed to WatchConnectivity.
        let notAfter: ContinuousClock.Instant? = switch patience {
        case .clock(let limit): start + limit
        case .awake: nil
        }
        var awake = Duration.zero
        var last = start
        // Activation and reachability arrive asynchronously after launch, and come back after a dropout.
        waiting: while session.activationState != .activated || !session.isReachable {
            switch patience {
            case .awake(let limit): if awake >= limit { break waiting }
            case .clock: if let notAfter, ContinuousClock.now >= notAfter { break waiting }
            }
            try await Task.sleep(for: ConnectionPolicy.reachabilityPoll)
            let now = ContinuousClock.now
            awake += min(now - last, ConnectionPolicy.maxAwakeStep)
            last = now
            await noteWaitingForPhone()
        }
        let waited = ContinuousClock.now - start
        guard session.activationState == .activated, session.isReachable else {
            WatchLog.warning("\(method): phone not reachable after \(waited.ms) ms (\(Self.describe(session)))")
            outcome = .connectionFailed
            throw PhoneError.notReachable
        }
        if let notAfter, ContinuousClock.now >= notAfter {
            WatchLog.warning("\(method): not sent, \(waited.ms) ms after it was asked for")
            outcome = .connectionFailed
            throw PhoneError.expired
        }

        if !probe { await noteSent() }
        // A reply that never comes must still end in an error, not in endless placeholders
        let number = SentNumber()
        do {
            let reply = try await withThrowingTaskGroup(of: [String: Any].self) { group in
                group.addTask { try await Self.send(method, args, notAfter: notAfter, number: number) }
                group.addTask {
                    try await Task.sleep(for: replyTimeout)
                    throw PhoneError.noAnswer
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            WatchLog.fine("\(method) #\(number.value): ok in \((ContinuousClock.now - start).ms) ms (waited \(waited.ms) ms)")
            outcome = .answered
            await noteAnswered()
            return reply
        } catch {
            let level = error is CancellationError ? WatchLog.fine : WatchLog.warning
            level("\(method) #\(number.value): \(Self.describe(error)) after \((ContinuousClock.now - start).ms) ms (waited \(waited.ms) ms, \(Self.describe(session)))")
            outcome = Self.outcome(of: error)
            if outcome == .answered {
                await noteAnswered()
            } else if outcome == .connectionFailed, session.isReachable {
                // Sent, the phone in reach, and still nothing came back.
                await noteUnanswered(session)
            }
            throw error
        }
    }

    // Shown only as the warning under the clock, never as a message (`PhoneMessage.show`).
    static func isConnectionFailure(_ error: Error) -> Bool { outcome(of: error) == .connectionFailed }

    // What a failed request says about the connection (`PhoneActivity`).
    private static func outcome(of error: Error) -> PhoneActivity.Outcome {
        switch error {
        case PhoneError.notReachable, PhoneError.noAnswer:
            return .connectionFailed
        // The phone answered: an error of its own, or a reply the watch didn't expect.
        case PhoneError.phone, PhoneError.serverUnreachable, PhoneError.unexpectedReply:
            return .answered
        // Not sent: the phone wasn't in reach in time.
        case PhoneError.expired, PhoneError.notAnswering:
            return .connectionFailed
        case let error as WCError:
            switch error.code {
            case .notReachable, .messageReplyTimedOut, .messageReplyFailed, .deliveryFailed, .transferTimedOut,
                 .sessionNotActivated, .sessionInactive, .genericError:
                return .connectionFailed
            // Payload, parameter, pairing or installation errors aren't a dropout.
            default:
                return .neutral
            }
        default:
            return .neutral
        }
    }

    // For the log: the kind of failure, never its text (a phone message can hold names).
    private static func describe(_ error: Error) -> String {
        switch error {
        case let error as PhoneError:
            switch error {
            case .notReachable: return "not reachable"
            case .phone: return "phone error"
            case .serverUnreachable: return "server unreachable"
            case .noAnswer: return "no answer"
            case .unexpectedReply: return "unexpected reply"
            case .expired: return "not sent in time"
            case .notAnswering: return "held back, the phone isn't answering"
            }
        case is CancellationError: return "cancelled"
        default:
            let error = error as NSError
            return "\(error.domain) \(error.code)"
        }
    }

    nonisolated private static func describe(_ session: WCSession) -> String {
        "session \(session.activationState.rawValue), reachable \(session.isReachable), scene \(shared.scene)"
    }

    // For the log: where the app is (active, inactive, background), as SwiftUI last reported it. A request can wait or
    // fail while the app runs off screen, and the same line means something else there.
    private let sceneLock = NSLock()
    private var sceneName = "starting"
    @MainActor func noteScene(_ name: String) {
        sceneLock.lock()
        sceneName = name
        sceneLock.unlock()
        if name != "active" { stopCountingSilence() }
        if name == "inactive" || name == "background" { closeWhileOffScreen() }
    }

    // In reach and not answering, and the wrist went down: close now, while nothing is on screen, so the next time
    // Finamp is opened it starts fresh. On 27 Nov 2026 (05:34:21) a fresh start answered within 4 s, and nothing
    // else has ever ended this state; it never ended by itself (05:35-05:39). No notice: the screen is off (yalit,
    // 27 Nov 2026: "close while the wrist down").
    @MainActor private func closeWhileOffScreen() {
        guard notAnswering else { return }
        WatchLog.warning("connection: closing while off screen (not answering for \(Int(-(notAnsweringSince ?? Date()).timeIntervalSinceNow)) s, \(unansweredChecks) basic requests unanswered)")
        WatchLog.shared.flush()
        exit(0)
    }
    private var scene: String {
        sceneLock.lock()
        defer { sceneLock.unlock() }
        return sceneName
    }

    // For the log: every request handed to WatchConnectivity carries the next number ("n"), in the order they are
    // handed over, so Finamp on the iPhone can log which never arrived.
    private static let numberLock = NSLock()
    private static var lastNumber = 0
    private final class SentNumber: @unchecked Sendable { var value = 0 }

    nonisolated private static func send(
        _ method: String, _ args: [String: Any], notAfter: ContinuousClock.Instant? = nil, number: SentNumber
    ) async throws -> [String: Any] {
        let gate = ReplyGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard gate.start(continuation) else { return }
                if let notAfter, ContinuousClock.now >= notAfter {
                    gate.finish(.failure(PhoneError.expired))
                    return
                }
                numberLock.lock()
                defer { numberLock.unlock() }
                lastNumber += 1
                number.value = lastNumber
                WCSession.default.sendMessage(
                    ["method": method, "args": args, "n": lastNumber],
                    replyHandler: { reply in
                        if let message = reply["error"] as? String {
                            gate.finish(.failure(reply["code"] as? String == "server"
                                ? PhoneError.serverUnreachable : PhoneError.phone(message)))
                        } else {
                            gate.finish(.success(reply))
                        }
                    },
                    errorHandler: { error in gate.finish(.failure(error)) }
                )
            }
        } onCancel: {
            // The timeout cancels the request; WatchConnectivity may still answer much later
            gate.finish(.failure(CancellationError()))
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            WatchLog.warning("session activation failed: \((error as NSError).domain) \((error as NSError).code)")
        } else {
            WatchLog.info("session activated (\(Self.describe(session)))")
        }
    }

    // The phone's live updates: it sends one at a time and waits for this empty reply before the next (`WatchBridge`).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler([:])
        self.session(session, didReceiveMessage: message)
    }

    // An update sent without asking for a reply (a Finamp from before the phone confirmed its updates).
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        WatchLog.fine("push: \(message.keys.sorted().joined(separator: ", "))")
        DispatchQueue.main.async {
            self.noteReceived()
            self.lastLiveUpdate = Date()
            self.apply(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        WatchLog.fine("context: \(applicationContext.keys.sorted().joined(separator: ", "))")
        DispatchQueue.main.async {
            self.noteReceived()
            self.lastContext = Date()
            self.apply(applicationContext)
        }
    }

    // Post notification when phone becomes reachable to retry failed loads.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        WatchLog.info("reachable \(session.isReachable)")
        guard session.isReachable else {
            DispatchQueue.main.async { self.stopCountingSilence() }
            return
        }
        DispatchQueue.main.async {
            self.phoneReachedAgain()
            NotificationCenter.default.post(name: .phoneBecameReachable, object: nil)
        }
    }
}

extension Notification.Name {
    static let phoneBecameReachable = Notification.Name("phoneBecameReachable")
}

// Resumes continuation exactly once on reply, error, or cancellation.
nonisolated private final class ReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[String: Any], Error>?
    private var result: Result<[String: Any], Error>?

    // Cancellation can arrive before the continuation is installed.
    func start(_ continuation: CheckedContinuation<[String: Any], Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let result {
            continuation.resume(with: result)
            return false
        }
        self.continuation = continuation
        return true
    }

    func finish(_ result: Result<[String: Any], Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard self.result == nil else { return }
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension Duration {
    var ms: Int64 { components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000 }
}

// Phone calls, as the watch sees them (CallKit's observer: only that a call rings, connects and ends, never who).
// After one ends the connection is checked at once (`ConnectionPolicy.Health.probeAfterCall`).
extension PhoneConnection: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        let state = call.hasEnded ? "ended" : call.hasConnected ? "connected" : call.isOutgoing ? "dialling" : "ringing"
        WatchLog.info("phone call \(state) (\(Self.describe(WCSession.default)))")
        guard call.hasEnded else { return }
        DispatchQueue.main.async { self.callEnded() }
    }
}
