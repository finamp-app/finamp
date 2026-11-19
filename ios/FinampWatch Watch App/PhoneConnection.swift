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
    // Token-free URL; empty when only the phone can supply the cover.
    var artworkURL = ""
    var blurHash = ""
    // Album artist for albums, first artist for tracks.
    var artistID = ""
    var artistArtworkURL = ""
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
            let url = artist["artworkUrl"] as? String ?? ""
            return LibraryItem(
                id: id,
                name: artist["name"] as? String ?? "",
                subtitle: "",
                artworkKey: id.isEmpty ? "" : "artist-\(id)",
                artworkURL: url
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
            return rows.compactMap { row in
                guard let index = row["index"] as? Int else { return nil }
                return QuickAction(index: index, title: row["title"] as? String ?? "", action: row["action"] as? String ?? "")
            }
        }
        set {
            let rows = newValue?.map { ["index": $0.index, "title": $0.title, "action": $0.action] as [String: Any] }
            UserDefaults.standard.set(rows, forKey: "quickActions")
        }
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
    let albums: [LibraryItem]
    let playlists: [LibraryItem]
    let tracks: [LibraryItem]

    var isEmpty: Bool { artists.isEmpty && albums.isEmpty && playlists.isEmpty && tracks.isEmpty }
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

    var errorDescription: String? {
        switch self {
        case .notReachable: return String(localized: "Can't reach your iPhone")
        case .serverUnreachable: return String(localized: "Can't reach your Jellyfin server")
        case .noAnswer: return String(localized: "Your iPhone didn't answer")
        case .phone(let message): return message
        case .unexpectedReply: return String(localized: "Unexpected reply from your iPhone")
        case .expired: return String(localized: "Not sent: your iPhone wasn't in reach in time")
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
        let actions = ((sections["actions"] as? [[String: Any]]) ?? []).compactMap { row -> QuickAction? in
            guard let index = row["index"] as? Int else { return nil }
            return QuickAction(index: index, title: row["title"] as? String ?? "", action: row["action"] as? String ?? "")
        }
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
        // It didn't get through.
        case failed
    }

    // Sends the crown's newest value until the phone confirms it, for up to `VolumeSend.giveUpAfter` from the newest
    // turn (an exact value: the phone applying it twice changes nothing; the phone applies requests in the order they
    // arrive, so the last to reach it wins). Confirmed only by the phone's `true` to that send, or by reading the
    // phone's volume when it may have arrived (a slow answer isn't a lost message: a phone waking Finamp answered in up
    // to 3 s, 19 Nov), never by a pushed volume, which may be old. A newer turn is sent instead of checking an older
    // one. If nothing gets through, the crown shows the phone's last known volume again.
    private func sendVolumes() async {
        let volumes = PhoneVolume.shared
        let token = PhoneActivity.shared.begin()
        var outcome = PhoneActivity.Outcome.neutral
        var refusal: String?
        defer { PhoneActivity.shared.end(token, outcome) }
        do {
            while let volume = volumes.wanted {
                let deadline = wantedAt + VolumeSend.giveUpAfter
                guard ContinuousClock.now < deadline else {
                    WatchLog.warning("setVolume: gave up, \(VolumeSend.giveUpAfter) after the newest turn")
                    volumes.wanted = nil
                    if outcome == .answered, let refusal { PhoneMessage.shared.text = refusal }
                    return
                }
                guard WCSession.default.isReachable else {
                    outcome = .connectionFailed
                    try await waitForPhone(until: min(.now + VolumeSend.retryAfterError, deadline))
                    continue
                }
                switch try await sendVolume(volume, before: deadline) {
                case .accepted:
                    outcome = .answered
                    volumes.observed(volume, accepted: true)
                    if volumes.wanted == volume { volumes.wanted = nil }
                case .uncertain:
                    outcome = .connectionFailed
                    // A newer turn is waiting: send that rather than check this one.
                    guard volumes.wanted == volume else { continue }
                    let read = try await readVolume(before: deadline)
                    if read.answered { outcome = .answered }
                    if let actual = read.volume, abs(actual - volume) < 0.005, volumes.wanted == volume {
                        volumes.wanted = nil
                    }
                case .refused(let message):
                    outcome = .answered
                    refusal = message
                    try await waitForPhone(until: min(.now + VolumeSend.retryAfterError, deadline))
                case .failed:
                    outcome = .connectionFailed
                    try await waitForPhone(until: min(.now + VolumeSend.retryAfterError, deadline))
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
            let reply = try await request("setVolume", ["volume": volume], replyTimeout: min(VolumeSend.noAnswerAfter, left),
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

    // The phone's volume read now (the Output sheet's request), before `deadline`. `answered`: the phone replied,
    // even if with an error.
    private func readVolume(before deadline: ContinuousClock.Instant) async throws -> (volume: Double?, answered: Bool) {
        let left = deadline - .now
        guard left > .zero else { return (nil, false) }
        do {
            let reply = try await request("output", [:], replyTimeout: min(VolumeSend.noAnswerAfter, left),
                                          quiet: true, patience: .clock(left))
            guard let volume = (reply["result"] as? [String: Any])?["volume"] as? Double else { return (nil, true) }
            PhoneVolume.shared.observed(volume)
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
            try await Task.sleep(until: min(ContinuousClock.now + .milliseconds(100), until), clock: .continuous)
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

    func seek(to position: Double) async throws {
        _ = try await request("seek", ["position": position])
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
            downloadLock: reply["downloadLock"] as? String
        )
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
                artworkURL: row["artworkUrl"] as? String ?? "",
                blurHash: row["blurHash"] as? String ?? "",
                artistID: row["artistId"] as? String ?? "",
                artistArtworkURL: row["artistArtworkUrl"] as? String ?? "",
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

    // How long a request waits for the phone to be in reach before it's sent.
    private enum Patience {
        // Time the app runs: a page or cover asked for just before the wrist went down still loads when it's raised.
        case awake(Duration)
        // Real time, up to the moment it's sent: a command must not reach the phone long after it was given.
        case clock(Duration)
    }

    // Requests you made show their status under the clock (`PhoneActivity`); covers and the now-playing refresh, which
    // repeat on their own, don't.
    private static func patience(_ method: String) -> (wait: Patience, shown: Bool) {
        switch method {
        case "artworks", "nowPlaying": (.awake(.seconds(5)), false)
        // `sendVolumes` waits and shows the status itself.
        case "setVolume": (.awake(.zero), false)
        // Playback opens the album page with what it has if this doesn't answer soon.
        case "item": (.awake(.seconds(5)), true)
        case "list", "home", "search", "artistInfo", "downloadState", "queue", "output", "settings":
            (.awake(.seconds(20)), true)
        // Commands are sent once, never repeated: a repeated toggle undoes itself, a repeated skip skips twice.
        default: (.clock(.seconds(3)), true)
        }
    }

    private func request(
        _ method: String, _ args: [String: Any], replyTimeout: Duration = .seconds(30), quiet: Bool = false,
        patience override: Patience? = nil
    ) async throws -> [String: Any] {
        let session = WCSession.default
        let (byKind, shown) = Self.patience(method)
        let patience = override ?? byKind
        let token = shown && !quiet ? PhoneActivity.shared.begin() : nil
        var outcome = PhoneActivity.Outcome.neutral
        defer {
            // Any reply shows the connection works, shown request or not.
            if outcome == .answered { PhoneActivity.shared.answered() }
            if let token { PhoneActivity.shared.end(token, outcome) }
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
            try await Task.sleep(for: .milliseconds(100))
            // A gap much longer than the sleep is the app suspended (wrist down), not time spent waiting.
            let now = ContinuousClock.now
            awake += min(now - last, .milliseconds(500))
            last = now
        }
        let waited = ContinuousClock.now - start
        guard session.activationState == .activated, session.isReachable else {
            WatchLog.warning("\(method): phone not reachable after \(waited.ms) ms (\(Self.describe(session)))")
            outcome = .connectionFailed
            throw PhoneError.notReachable
        }
        if let notAfter, ContinuousClock.now >= notAfter {
            WatchLog.warning("\(method): not sent, \(waited.ms) ms after it was asked for")
            throw PhoneError.expired
        }

        // A reply that never comes must still end in an error, not in endless placeholders
        do {
            let reply = try await withThrowingTaskGroup(of: [String: Any].self) { group in
                group.addTask { try await Self.send(method, args, notAfter: notAfter) }
                group.addTask {
                    try await Task.sleep(for: replyTimeout)
                    throw PhoneError.noAnswer
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            WatchLog.fine("\(method): ok in \((ContinuousClock.now - start).ms) ms (waited \(waited.ms) ms)")
            outcome = .answered
            return reply
        } catch {
            let level = error is CancellationError ? WatchLog.fine : WatchLog.warning
            level("\(method): \(Self.describe(error)) after \((ContinuousClock.now - start).ms) ms (waited \(waited.ms) ms, \(Self.describe(session)))")
            outcome = Self.outcome(of: error)
            throw error
        }
    }

    // What a failed request says about the connection (`PhoneActivity`).
    private static func outcome(of error: Error) -> PhoneActivity.Outcome {
        switch error {
        case PhoneError.notReachable, PhoneError.noAnswer:
            return .connectionFailed
        // The phone answered: an error of its own, or a reply the watch didn't expect.
        case PhoneError.phone, PhoneError.serverUnreachable, PhoneError.unexpectedReply:
            return .answered
        // Not sent because it was too late: nothing about the connection.
        case PhoneError.expired:
            return .neutral
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
            }
        case is CancellationError: return "cancelled"
        default:
            let error = error as NSError
            return "\(error.domain) \(error.code)"
        }
    }

    nonisolated private static func describe(_ session: WCSession) -> String {
        "session \(session.activationState.rawValue), reachable \(session.isReachable)"
    }

    nonisolated private static func send(
        _ method: String, _ args: [String: Any], notAfter: ContinuousClock.Instant? = nil
    ) async throws -> [String: Any] {
        let gate = ReplyGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard gate.start(continuation) else { return }
                if let notAfter, ContinuousClock.now >= notAfter {
                    gate.finish(.failure(PhoneError.expired))
                    return
                }
                WCSession.default.sendMessage(
                    ["method": method, "args": args],
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

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        WatchLog.fine("push: \(message.keys.sorted().joined(separator: ", "))")
        DispatchQueue.main.async { self.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        WatchLog.fine("context: \(applicationContext.keys.sorted().joined(separator: ", "))")
        DispatchQueue.main.async { self.apply(applicationContext) }
    }

    // Post notification when phone becomes reachable to retry failed loads.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        WatchLog.info("reachable \(session.isReachable)")
        guard session.isReachable else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .phoneBecameReachable, object: nil)
        }
    }
}

// How a volume change is sent when it doesn't get through (`sendVolumes`).
enum VolumeSend {
    // After a send that failed (phone out of reach, a WatchConnectivity error, a refusal) the next one goes this long
    // after it began, or as soon as the phone is back in reach.
    static let retryAfterError: Duration = .seconds(1)
    // A send waits this long for its answer before the phone is asked for its volume: normal requests take 0.1-0.6 s
    // on the devices, a phone waking Finamp in the background answered in up to 3 s (simulator, 19 Nov).
    static let noAnswerAfter: Duration = .seconds(3)
    // Nothing confirmed this long after the newest crown turn: give up and show the phone's last known volume.
    static let giveUpAfter: Duration = .seconds(20)
    // Just after the phone accepted a change, a different volume it pushes is taken as an older one still on its way.
    static let olderPushWindow: TimeInterval = 1.5
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

private extension Duration {
    var ms: Int64 { components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000 }
}
