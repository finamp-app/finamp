import Foundation
import OSLog
import WatchConnectivity

// The watch's log, for finding bugs that only a real watch shows. Each line goes to Apple's unified log (Console, a
// sysdiagnose), to a capped file on the watch, and in batches to Finamp on the iPhone, which adds them to its own logs
// (Settings → Logs, with Finamp's copy, share and export). Lines hold states, request names, timings and error kinds:
// never names, IDs or addresses.
final class WatchLog: @unchecked Sendable {
    enum Level: String {
        // Routine events; Finamp keeps them only with Verbose Logging on, like its own FINE lines.
        case fine
        case info
        case warning
    }

    static let shared = WatchLog()

    static func fine(_ message: String) { shared.add(.fine, message) }
    static func info(_ message: String) { shared.add(.info, message) }
    static func warning(_ message: String) { shared.add(.warning, message) }

    private let system = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinampWatch", category: "watch")
    private let queue = DispatchQueue(label: "WatchLog")
    private var lines: [String] = []
    private var unsent: [[String: Any]] = []
    private var timer: DispatchSourceTimer?
    private let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("watch-log.txt")

    private static let fileLines = 2000
    private static let batchSize = 50
    // Lines waiting for the phone while it's out of reach; the oldest go first.
    private static let unsentLimit = 1000

    private init() {
        lines = (try? String(contentsOf: file, encoding: .utf8))?.split(separator: "\n").suffix(Self.fileLines).map(String.init) ?? []
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in self?.send() }
        timer.resume()
        self.timer = timer
    }

    private func add(_ level: Level, _ message: String) {
        switch level {
        case .fine: system.debug("\(message, privacy: .public)")
        case .info: system.info("\(message, privacy: .public)")
        case .warning: system.error("\(message, privacy: .public)")
        }
        let time = Date()
        queue.async { [self] in
            lines.append("\(time.ISO8601Format(.iso8601.time(includingFractionalSeconds: true))) \(level.rawValue) \(message)")
            if lines.count > Self.fileLines { lines.removeFirst(lines.count - Self.fileLines) }
            unsent.append(["t": time.timeIntervalSince1970, "l": level.rawValue, "m": message])
            if unsent.count > Self.unsentLimit { unsent.removeFirst(unsent.count - Self.unsentLimit) }
            if unsent.count >= Self.batchSize { send() }
        }
    }

    // Also when the app leaves the screen, so a session's last lines aren't held back.
    func flush() {
        queue.async { [self] in send() }
    }

    // On `queue`. WatchConnectivity queues user info and delivers it whenever the phone can take it, even after a drop.
    private func send() {
        try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        let session = WCSession.default
        guard !unsent.isEmpty, session.activationState == .activated else { return }
        for start in stride(from: 0, to: unsent.count, by: Self.batchSize) {
            session.transferUserInfo(["watchLog": Array(unsent[start..<min(start + Self.batchSize, unsent.count)])])
        }
        unsent.removeAll()
    }
}
