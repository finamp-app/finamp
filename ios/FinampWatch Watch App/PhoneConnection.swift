import Foundation
import WatchConnectivity

/// A library row received from the phone.
struct LibraryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    /// Image id + image tag; empty without a cover.
    let artworkKey: String
    /// Destination type for mixed lists; empty elsewhere.
    var kind = ""
    /// Seconds; 0 when unknown.
    var duration: Double = 0
    /// Release year; 0 when unknown.
    var year = 0
    /// An album's or playlist's number of tracks; 0 when unknown.
    var trackCount = 0
    /// Token-free Jellyfin URL; empty when only the phone can provide the cover.
    var artworkURL = ""
    /// Album's album artist or track's first artist; empty when unknown.
    var artistID = ""
    /// Artist photo URL; empty when unknown.
    var artistArtworkURL = ""
    var favorite = false
    /// Downloaded or queued on the phone.
    var downloaded = false
    /// Dependency download explanation; nil when not locked.
    var downloadLock: String?
    /// Album artists with photo URLs; empty for other item types.
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
    let theme: String
}

/// A Home quick action, identified by its index in the phone's configuration.
struct QuickAction: Identifiable, Hashable {
    let index: Int
    let title: String
    let action: String

    var id: Int { index }

    /// Cached for Home's first frame, before the phone replies.
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
    let favorite: Bool
    let downloaded: Bool
    let downloadLock: String?
}

/// A download question requested by the phone.
enum DownloadQuestion {
    /// Asked only when transcoding is not set to always or never.
    case transcode(transcodedLabel: String)
    /// Asked when several storage locations exist without a default.
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
    /// Finamp on the phone can't reach the Jellyfin server.
    case serverUnreachable
    /// The phone accepted a request but never answered.
    case noAnswer
    /// The watch cannot decode this reply, possibly due to a version mismatch.
    case unexpectedReply

    var errorDescription: String? {
        switch self {
        case .notReachable: return String(localized: "Can't reach your iPhone")
        case .serverUnreachable: return String(localized: "Can't reach your Jellyfin server")
        case .noAnswer: return String(localized: "Your iPhone didn't answer")
        case .phone(let message): return message
        case .unexpectedReply: return String(localized: "Unexpected reply from your iPhone")
        }
    }
}

/// Sends requests through the paired phone; the watch holds no Jellyfin token.
final class PhoneConnection: NSObject, WCSessionDelegate {
    static let shared = PhoneConnection()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        apply(WCSession.default.receivedApplicationContext)
    }

    /// Applies the theme before other state so the first frame has the correct appearance.
    private func apply(_ values: [String: Any]) {
        ThemeStore.shared.apply(values["theme"])
        AccountStore.shared.apply(values["account"])
        if let state = values["nowPlaying"] as? [String: Any] {
            NowPlayingStore.shared.update(from: state)
        }
        if let enabled = values["transcoding"] as? Bool { PhoneSettings.shared.transcoding = enabled }
        if let offline = values["offline"] as? Bool { PhoneSettings.shared.offline = offline }
        if let volume = values["volume"] as? Double { PhoneVolume.shared.value = volume }
        if let airPlay = values["airPlay"] as? Bool { PhoneVolume.shared.airPlay = airPlay }
    }

    /// Pages roots, or an album's or playlist's tracks, with `offset` and `limit`; an artist's albums come at once.
    /// `artists` follows the phone's artist type setting; other types are Finamp ContentType names.
    func list(_ type: String, parentId: String? = nil, offset: Int = 0, limit: Int = 50) async throws -> [LibraryItem] {
        var args: [String: Any] = ["type": type, "offset": offset, "limit": limit]
        if let parentId { args["parentId"] = parentId }
        let rows = try await request("list", args)["result"]
        guard rows is [[String: Any]] else { throw PhoneError.unexpectedReply }
        return Self.items(from: rows)
    }

    /// Fetches Home sections in one round trip.
    func home() async throws -> HomeSections {
        let sections = try await request("home", [:])["result"] as? [String: Any] ?? [:]
        let actions = ((sections["actions"] as? [[String: Any]]) ?? []).compactMap { row -> QuickAction? in
            guard let index = row["index"] as? Int else { return nil }
            return QuickAction(index: index, title: row["title"] as? String ?? "", action: row["action"] as? String ?? "")
        }
        return HomeSections(
            recent: Self.items(from: sections["recent"]),
            newAlbums: Self.items(from: sections["newAlbums"]),
            actions: actions,
            theme: sections["theme"] as? String ?? ""
        )
    }

    func search(_ query: String) async throws -> SearchResults {
        let sections = try await request("search", ["query": query])["result"] as? [String: Any] ?? [:]
        return SearchResults(
            artists: Self.items(from: sections["artists"]),
            albums: Self.items(from: sections["albums"]),
            playlists: Self.items(from: sections["playlists"]),
            tracks: Self.items(from: sections["tracks"])
        )
    }

    /// Phone output route and Finamp volume (0–1).
    func output() async throws -> (route: String, routeType: String, volume: Double) {
        let reply = try await request("output", [:])["result"] as? [String: Any] ?? [:]
        return (reply["route"] as? String ?? "", reply["routeType"] as? String ?? "", reply["volume"] as? Double ?? 1)
    }

    private var pendingVolume: Double?
    private var volumeInFlight = false

    /// Sets Finamp volume (0–1), coalescing changes behind one in-flight message.
    /// Sending every crown tick would queue stale values and delay volume changes.
    func setVolume(_ volume: Double) {
        pendingVolume = volume
        guard !volumeInFlight else { return }
        volumeInFlight = true
        Task {
            while let volume = pendingVolume {
                pendingVolume = nil
                _ = try? await request("setVolume", ["volume": volume])
            }
            volumeInFlight = false
        }
    }


    /// The phone checks `action` against `index` to reject a reordered quick-action list.
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

    /// "playPause", "next" or "previous".
    func control(_ action: String) async throws {
        _ = try await request("control", ["action": action])
    }

    /// Upcoming tracks; a row's `id` is what `skipTo` takes.
    func queue() async throws -> [LibraryItem] {
        Self.items(from: try await request("queue", [:])["result"])
    }

    /// Returns the resulting favourite state, unchanged while Finamp is offline.
    func setFavorite(_ id: String, _ favorite: Bool) async throws -> Bool {
        guard let result = try await request("favorite", ["id": id, "favorite": favorite])["result"] as? Bool else {
            throw PhoneError.unexpectedReply
        }
        return result
    }

    /// Returns a question or download status; repeat with accumulated answers for each question.
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

    /// Returns false when queued until Finamp is foregrounded on the phone (within two minutes).
    func showOutputPicker() async throws -> Bool {
        try await request("showOutputPicker", [:])["result"] as? String == "shown"
    }

    /// Finamp's "Enable Transcoding" and "Offline Mode" settings on the phone.
    func settings() async throws -> (transcoding: Bool, offline: Bool) {
        guard let result = try await request("settings", [:])["result"] as? [String: Any] else {
            throw PhoneError.unexpectedReply
        }
        return (result["transcoding"] as? Bool ?? false, result["offline"] as? Bool ?? false)
    }

    /// Changes one of those settings ("transcoding" or "offline") on the phone.
    func setSetting(_ name: String, _ enabled: Bool) async throws {
        _ = try await request("setSetting", ["name": name, "enabled": enabled])
    }

    func artistInfo(_ id: String) async throws -> ArtistInfo {
        let reply = try await request("artistInfo", ["id": id])["result"] as? [String: Any] ?? [:]
        if let favorite = reply["favorite"] as? Bool {
            FavoriteOverrides.shared.phoneReported(id, favorite)
        }
        return ArtistInfo(
            tracks: reply["tracks"] as? Int ?? 0,
            favorite: reply["favorite"] as? Bool ?? false,
            downloaded: reply["downloaded"] as? Bool ?? false,
            downloadLock: reply["downloadLock"] as? String
        )
    }

    /// Fetches current download state; `lock` explains a dependency download, or is nil.
    func downloadState(_ id: String) async throws -> (downloaded: Bool, lock: String?) {
        let reply = try await request("downloadState", ["id": id])["result"] as? [String: Any] ?? [:]
        return (reply["downloaded"] as? Bool ?? false, reply["downloadLock"] as? String)
    }

    /// Jumps to an upcoming queue row by its `id`; the phone finds where it is now.
    func skipTo(id: String) async throws {
        _ = try await request("control", ["action": "skipTo", "id": id])
    }

    /// Plays a collection, favourites, or search results (`extra["query"]`), optionally from `startId`.
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
                trackCount: row["trackCount"] as? Int ?? 0,
                artworkURL: row["artworkUrl"] as? String ?? "",
                artistID: row["artistId"] as? String ?? "",
                artistArtworkURL: row["artistArtworkUrl"] as? String ?? "",
                favorite: row["favorite"] as? Bool ?? false,
                downloaded: row["downloaded"] as? Bool ?? false,
                downloadLock: row["downloadLock"] as? String,
                artists: LibraryItem.artists(from: row["artists"])
            )
        }
    }

    /// Plays the displayed Tracks page from `startId`.
    func playTracks(offset: Int, limit: Int, startId: String) async throws {
        _ = try await request("play", ["type": "tracks", "offset": offset, "limit": limit, "startId": startId])
    }

    /// JPEGs capped at `size` pixels on the longer side, keyed "<id>-<size>"; `missing` means no cover.
    /// Keys in neither set exceeded the reply budget and must be retried.
    func artworks(_ requests: [(id: String, size: Int)]) async throws -> (covers: [String: Data], missing: Set<String>) {
        let reply = try await request("artworks", ["items": requests.map { ["id": $0.id, "size": $0.size] }])
        return (reply["artworks"] as? [String: Data] ?? [:], Set(reply["missing"] as? [String] ?? []))
    }

    private func request(_ method: String, _ args: [String: Any]) async throws -> [String: Any] {
        let session = WCSession.default
        // Activation and reachability arrive asynchronously after launch.
        for _ in 0..<50 where session.activationState != .activated || !session.isReachable {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard session.activationState == .activated, session.isReachable else { throw PhoneError.notReachable }

        // A reply that never comes must still end in an error, not in endless placeholders
        return try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask { try await Self.send(method, args) }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw PhoneError.noAnswer
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    nonisolated private static func send(_ method: String, _ args: [String: Any]) async throws -> [String: Any] {
        let gate = ReplyGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard gate.start(continuation) else { return }
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

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(applicationContext) }
    }

    /// Lets failed pages retry when the phone becomes reachable.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .phoneBecameReachable, object: nil)
        }
    }
}

extension Notification.Name {
    static let phoneBecameReachable = Notification.Name("phoneBecameReachable")
}

/// Resumes a request exactly once: on its reply, its error or its cancellation, whichever comes first.
nonisolated private final class ReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[String: Any], Error>?
    private var result: Result<[String: Any], Error>?

    /// False when the request was cancelled before it started.
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
