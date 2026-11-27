import AVKit
import CallKit
import Flutter
import ImageIO
import UIKit
import WatchConnectivity

// Relays watch requests to WatchHandler and forwards updates.

private var watchChannel: FlutterMethodChannel?
private let watchBridge = WatchBridge()

extension AppDelegate {
    func setupWatchChannel() {
        // Must match WatchHandler even in builds with a different bundle ID.
        watchChannel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp-ios/watch",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        watchChannel?.setMethodCallHandler { call, result in
            // Relay only state updates; queries such as watchState must be answered here.
            switch call.method {
            case "nowPlaying" where call.arguments is [String: Any],
                 "accent" where call.arguments is [String: Any],
                 "account" where call.arguments is String,
                 "transcoding" where call.arguments is Bool,
                 "offline" where call.arguments is Bool,
                 "preferFavorites" where call.arguments is Bool,
                 "volume" where call.arguments is Double,
                 "airPlay" where call.arguments is Bool,
                 "favoriteStates" where call.arguments is [String: Any],
                 "outputRoute" where call.arguments is [String: Any]:
                watchBridge.push(key: call.method, value: call.arguments!)
                result(nil)
            case "watchState":
                result(watchBridge.isWatchAppAvailable)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        watchBridge.activate()
    }
}

private final class WatchBridge: NSObject, WCSessionDelegate {
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        // For the log: iOS limits what Finamp may do in the background, so the watch's lines need to say where it was.
        for (name, text) in [
            (UIApplication.didEnterBackgroundNotification, "Finamp went to the background"),
            (UIApplication.willEnterForegroundNotification, "Finamp came to the foreground"),
        ] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.isWatchAppAvailable else { return }
                self.log("info", text)
            }
        }
        callObserver.setDelegate(self, queue: .main)
        // A shared state still waiting for its turn goes before Finamp can be suspended or closed.
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.willTerminateNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.contextDue else { return }
                self.sendContext(now: true)
            }
        }
    }

    // Phone calls: that one rings, connects and ends (CallKit's observer tells nothing else, no number or name). On
    // 26 Nov 2026 the watch stopped getting answers right after calls, so they are logged.
    //
    // And music during a call: iOS pauses Finamp when a call rings and lets it play again when the call is declined or
    // over. But when the call is taken on another device (the watch), iOS hands the audio back at once and the music
    // plays through the conversation (26 Nov 2026: taken on the watch 21:12:19.06, playing again 21:12:19.3; Apple's
    // Music app does the same). So: playback that begins within `resumeWindow` of a call connecting is paused, and
    // played again when the last call ends, unless the user changed it meanwhile. Later than that, music started
    // during a call is the user's own choice.
    private let callObserver = CXCallObserver()
    private var connectedCalls: Set<UUID> = []
    private var callConnectedAt: Date?
    private var pausedForCall = false
    // iOS handed the audio back 0.2-0.3 s after the call was taken; Finamp's update follows within 150 ms.
    private static let resumeWindow: TimeInterval = 5

    private var isPlaying: Bool { (context["nowPlaying"] as? [String: Any])?["playing"] as? Bool == true }

    fileprivate func callChanged(_ call: CXCall) {
        if call.hasEnded {
            guard connectedCalls.remove(call.uuid) != nil, connectedCalls.isEmpty else { return }
            callConnectedAt = nil
            guard pausedForCall else { return }
            pausedForCall = false
            guard !isPlaying else { return }
            log("info", "the call is over: playing again")
            watchChannel?.invokeMethod("control", arguments: ["action": "play"])
        } else if call.hasConnected, connectedCalls.insert(call.uuid).inserted {
            if callConnectedAt == nil { callConnectedAt = Date() }
            pauseForCall()
        }
    }

    private func pauseForCall() {
        guard !pausedForCall, isPlaying, let since = callConnectedAt,
              Date().timeIntervalSince(since) < Self.resumeWindow else { return }
        pausedForCall = true
        log("info", "music playing during a phone call taken on another device: paused until it ends")
        watchChannel?.invokeMethod("control", arguments: ["action": "pause"])
    }

    // updateApplicationContext replaces entire context; keep all keys.
    private var context: [String: Any] = [:]

    func push(key: String, value: Any) {
        guard WCSession.isSupported() else { return }
        // Clear playback on account change.
        if key == "account", context["account"] as? String != value as? String {
            context["nowPlaying"] = nil
            waitingLive["nowPlaying"] = nil
        }
        context[key] = value
        if key == "nowPlaying" { pauseForCall() }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired else { return }
        sendContext(now: false)
        if session.isReachable {
            waitingLive[key] = value
            sendWaitingLive()
        }
    }

    // The shared state (application context) backs up the live updates: it reaches the watch app whatever happens to
    // a live update, and is what a watch app starting up reads first. Sending it with every live update doubled the
    // phone's traffic (27 Nov 2026: 310 live updates and 337 contexts in six hours), so while the watch is in reach it
    // goes at most every `contextEvery` with the latest values, and at once when the watch is out of reach, when a live
    // update fails, when the watch goes out of reach with a newer one unsent, and before Finamp is suspended or closed
    // (yalit, 27 Nov 2026: "send to the shared every few seconds").
    private static let contextEvery: TimeInterval = 3
    private var contextDue = false
    private var contextTimerSet = false

    private func sendContext(now: Bool) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, !context.isEmpty else { return }
        if now || !session.isReachable {
            contextDue = false
            try? session.updateApplicationContext(context)
            return
        }
        contextDue = true
        guard !contextTimerSet else { return }
        contextTimerSet = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.contextEvery) { [weak self] in
            guard let self else { return }
            self.contextTimerSet = false
            if self.contextDue { self.sendContext(now: true) }
        }
    }

    // Live updates go out one at a time: each is confirmed by the watch (an empty reply) before the next is sent, and
    // values that change meanwhile wait and go together, the newest of each. So never more than one live update is
    // undelivered. On 26 Nov 2026 a Finamp that started while the iPhone was holding its traffic sent ten separate
    // updates within 1.4 s; none was delivered, WatchConnectivity stopped accepting messages from that process, and
    // every answer to the watch stayed behind them until Finamp was restarted. The application context above carries
    // the same values whatever happens to a live update, so one that fails is not sent again.
    private var waitingLive: [String: Any] = [:]
    private var liveInFlightSince: Date?

    private func sendWaitingLive() {
        let session = WCSession.default
        guard !waitingLive.isEmpty, session.isReachable else { return }
        if let since = liveInFlightSince {
            // For the log: the one before is still unconfirmed. Delivery takes 0.2-0.5 s on the devices.
            let waited = Date().timeIntervalSince(since)
            if waited >= 10, !warnedLiveUnconfirmed {
                warnedLiveUnconfirmed = true
                log("warning", "live update unconfirmed for \(Int(waited)) s; newer values wait for it (\(describeState()))")
            }
            return
        }
        let values = waitingLive
        waitingLive = [:]
        let handedOver = Date()
        liveInFlightSince = handedOver
        warnedLiveUnconfirmed = false
        let kinds = values.keys.sorted().joined(separator: ", ")
        session.sendMessage(values, replyHandler: { [weak self] _ in
            DispatchQueue.main.async { self?.liveEnded() }
        }, errorHandler: { [weak self] error in
            let error = error as NSError
            let age = Date().timeIntervalSince(handedOver)
            DispatchQueue.main.async {
                self?.liveFailed(kinds, "\(error.domain) \(error.code)", age)
                self?.liveEnded()
            }
        })
    }

    private var warnedLiveUnconfirmed = false

    private func liveEnded() {
        liveInFlightSince = nil
        sendWaitingLive()
    }

    // A live update that fails is logged, nothing else. One that fails long after it was handed over sat undelivered:
    // on 26 Nov 2026 the iPhone held Finamp's messages for six minutes while the watch counted as reachable, and
    // Finamp's log showed nothing.
    // One line for failures that come together. A warning when the oldest had waited 2 s or more (delivery takes
    // 0.2-0.5 s on the devices); otherwise the routine loss of an update sent as the wrist went down.
    private var failedLive: [(what: String, error: String, age: TimeInterval)] = []

    private func liveFailed(_ what: String, _ error: String, _ age: TimeInterval) {
        sendContext(now: true)
        failedLive.append((what, error, age))
        guard failedLive.count == 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let group = failedLive
            failedLive = []
            let oldest = group.map(\.age).max() ?? 0
            let errors = Set(group.map(\.error)).sorted().joined(separator: ", ")
            let kinds = Set(group.map(\.what)).sorted().joined(separator: ", ")
            log(oldest >= 2 ? "warning" : "fine",
                "\(group.count) live update(s) not delivered (\(kinds): \(errors)); the oldest was handed over \(Int(oldest * 1000)) ms before (\(describeState()))")
        }
    }

    // On the main thread.
    private func describeState() -> String {
        let app = switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
        return "watch reachable \(WCSession.default.isReachable), Finamp \(app)"
    }

    // The watch numbers its requests ("n", in the order it hands them to WatchConnectivity): a gap is requests that
    // never arrived. The last number is kept across Finamp's launches, since quitting Finamp is what people try when
    // the watch stops answering; a smaller number is the watch app started again.
    private static let lastRequestKey = "watchLastRequestNumber"

    private func noteRequest(_ method: String, _ number: Int?) {
        guard let number else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastRequestKey) as? Int
        if let last, number > last + 1 {
            log("warning", "\(number - last - 1) request(s) from the watch never arrived (#\(last + 1) to #\(number - 1), before #\(number) \(method); \(describeState()))")
        }
        UserDefaults.standard.set(number, forKey: Self.lastRequestKey)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error as NSError? {
            log("warning", "session activation failed: \(error.domain) \(error.code)")
        } else {
            log("info", "session activated (paired \(session.isPaired), app installed \(session.isWatchAppInstalled))")
        }
        watchStateDidChange()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let time = Date()
        // Whenever the watch app comes back in reach (opened, raised, back in range), hand it the latest of every update:
        // a freshly installed watch app starts with an empty context, and updates sent while it was out of reach are
        // lost, while the phone repeats a value only when it changes.
        DispatchQueue.main.async { [self] in
            log("info", "\(describeState()) (the watch reported reachable \(reachable))", at: time)
            if !reachable, contextDue { sendContext(now: true) }
            guard reachable, !context.isEmpty else { return }
            // Everything, as one update; it replaces whatever was still waiting.
            waitingLive = context
            sendWaitingLive()
        }
    }

    // Finamp keeps these lines in its own logs (Settings → Logs), next to the watch's.
    fileprivate func logCall(_ text: String) { log("info", "\(text) (\(describeState()))") }

    private func log(_ level: String, _ message: String, at time: Date = Date()) {
        forwardLog([["t": time.timeIntervalSince1970, "l": level, "m": message, "s": "iPhone"]])
    }

    private func forwardLog(_ lines: [[String: Any]]) {
        DispatchQueue.main.async { watchChannel?.invokeMethod("watchLog", arguments: ["lines": lines]) }
    }

    // The watch's own log lines, queued by WatchConnectivity until the phone can take them. The watch never names a
    // source ("s"); one that does would pass its lines off as the iPhone's, so it is dropped (security review M-16).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let lines = userInfo["watchLog"] as? [[String: Any]] {
            forwardLog(lines.filter { flutterCanCarry($0) }.map { $0.filter { $0.key != "s" } })
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        watchStateDidChange()
    }

    var isWatchAppAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    private var wasInstalled = false

    private func watchStateDidChange() {
        DispatchQueue.main.async { [self] in
            let session = WCSession.default
            let paired = session.activationState == .activated && session.isPaired
            let installed = isWatchAppAvailable
            // iOS can report false for an installed app; only unpairing or a false transition means removed.
            let removed = !paired || (wasInstalled && !installed)
            log("fine", "watch state: paired \(paired), app installed \(installed)")
            wasInstalled = installed
            if paired, !context.isEmpty { try? session.updateApplicationContext(context) }
            if installed || removed {
                watchChannel?.invokeMethod("watchState", arguments: ["available": installed])
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for a newly paired watch.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler answer: @escaping ([String: Any]) -> Void) {
        guard let method = message["method"] as? String else {
            answer(["error": "Missing method"])
            return
        }
        // For the log: which request this is, and how long Finamp took to hand its answer to WatchConnectivity (iOS
        // doesn't tell whether an answer arrives). Kept only with Verbose Logging, unless it took 2 s or more.
        let number = message["n"] as? Int
        let received = Date()
        DispatchQueue.main.async { self.noteRequest(method, number) }
        let replyHandler: ([String: Any]) -> Void = { [weak self] reply in
            answer(reply)
            let ms = Int(Date().timeIntervalSince(received) * 1000)
            self?.log(ms >= 2000 ? "info" : "fine",
                      "request \(number.map { "#\($0) " } ?? "")\(method): \(reply["error"] == nil ? "answer" : "error answer") handed over after \(ms) ms")
        }
        // This bridge's own calls into Finamp, never requests: the watch's state comes from WatchConnectivity and its
        // log lines through `transferUserInfo`. A message naming them could stop the pushes or write to Finamp's log
        // (security review M-27).
        if method == "watchState" || method == "watchLog" {
            replyHandler(["error": "Update Finamp on your iPhone", "code": "unsupported"])
            return
        }
        guard flutterCanCarry(message["args"]) else {
            replyHandler(["error": "Finamp couldn't do that on your iPhone", "code": "error"])
            return
        }

        if method == "showOutputPicker" {
            DispatchQueue.main.async {
                replyHandler(["result": outputPicker.show() ? "shown" : "pending"])
            }
            return
        }

        DispatchQueue.main.async {
            guard let channel = watchChannel else {
                self.log("warning", "\(method): Finamp is still starting")
                replyHandler(["error": "Finamp is still starting"])
                return
            }
            channel.invokeMethod(method, arguments: message["args"]) { result in
                if let error = result as? FlutterError {
                    replyHandler(["error": error.message ?? error.code, "code": error.code])
                } else if (result as AnyObject?) === FlutterMethodNotImplemented {
                    replyHandler(["error": "Finamp is still starting"])
                } else if method == "artworks" {
                    // Encode off main thread to avoid stalling Finamp UI.
                    let args = message["args"]
                    DispatchQueue.global(qos: .userInitiated).async {
                        replyHandler(artworksReply(result, request: args))
                    }
                } else if let result = result, !(result is NSNull) {
                    replyHandler(["result": result])
                } else {
                    replyHandler([:])
                }
            }
        }
    }
}

extension WatchBridge: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        callChanged(call)
        guard isWatchAppAvailable else { return }
        let state = call.hasEnded ? "ended" : call.hasConnected ? "connected" : call.isOutgoing ? "dialling" : "ringing"
        logCall("phone call \(state)")
    }
}

private let outputPicker = OutputPicker()

// iOS has no public API to show route picker; tap hidden AVRoutePickerView button.
private final class OutputPicker: NSObject, AVRoutePickerViewDelegate {
    private let picker = AVRoutePickerView()
    private var pendingSince: Date?

    override init() {
        super.init()
        picker.prioritizesVideoDevices = false
        picker.delegate = self
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let since = self.pendingSince else { return }
            self.pendingSince = nil
            if Date().timeIntervalSince(since) < 120 { _ = self.show() }
        }
    }

    // Queue request up to two minutes if phone is locked.
    func show() -> Bool {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive && $0.session.role == .windowApplication }
        guard let window = scene?.windows.first(where: \.isKeyWindow),
              let button = findButton(in: picker) else {
            pendingSince = Date()
            return false
        }
        pendingSince = nil
        // Must stay in window as invisible anchor.
        picker.frame = CGRect(x: window.bounds.midX - 1, y: window.safeAreaInsets.top + 40, width: 2, height: 2)
        picker.alpha = 0.011
        if picker.window !== window { window.addSubview(picker) }
        button.sendActions(for: .touchUpInside)
        return true
    }

    // Remove after dismissal so it cannot intercept taps.
    func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        picker.removeFromSuperview()
    }

    private func findButton(in view: UIView) -> UIButton? {
        for subview in view.subviews {
            if let button = subview as? UIButton ?? findButton(in: subview) { return button }
        }
        return nil
    }
}

// Whether Flutter's standard codec can carry a value the watch sent. WatchConnectivity also delivers dates, and the
// codec stops the app on a type it doesn't know (an assertion in `FlutterStandardWriter`): one message holding a date
// ended Finamp (found with the security rig, 25 Nov 2026). The watch app sends only the types below.
private func flutterCanCarry(_ value: Any?) -> Bool {
    guard let value else { return true }
    if value is NSNull || value is NSNumber || value is String || value is Data { return true }
    if let list = value as? [Any] { return list.allSatisfy { flutterCanCarry($0) } }
    if let map = value as? [String: Any] { return map.values.allSatisfy { flutterCanCarry($0) } }
    return false
}

// Budget below WatchConnectivity's ~64 KB reply limit.
private let artworksReplyBudget = 48 * 1024

// Return JPEGs and missing keys as <id>-<size>; omit budget-deferred keys for retry.
private func artworksReply(_ result: Any?, request: Any?) -> [String: Any] {
    let requested = ((request as? [String: Any])?["items"] as? [[String: Any]]) ?? []
    let results = (result as? [[String: Any]]) ?? []

    var artworks: [String: Data] = [:]
    var missing: [String] = []
    var bytes = 0
    for (item, entry) in zip(requested, results) {
        guard let id = item["id"] as? String, let size = item["size"] as? Int else { continue }
        let key = "\(id)-\(size)"
        // Reject out-of-range sizes; Dart clamps the size it asks the server for.
        guard (16...1200).contains(size) else {
            missing.append(key)
            continue
        }
        // Not ready yet: left out of both, so the watch asks again.
        if entry["later"] as? Bool == true { continue }
        // Covers arrive as their files' paths (JPEG/PNG, any size) and are scaled here, outside Flutter, straight from
        // the file: its bytes are never held in memory (security review M-07).
        let source = (entry["path"] as? String).flatMap {
            CGImageSourceCreateWithURL(URL(fileURLWithPath: $0) as CFURL, nil)
        }
        guard let source, let jpeg = resizedJPEG(source, maxSide: CGFloat(size)) else {
            missing.append(key)
            continue
        }
        if bytes + jpeg.count > artworksReplyBudget && !artworks.isEmpty { continue }
        artworks[key] = jpeg
        bytes += jpeg.count
    }
    return ["artworks": artworks, "missing": missing]
}

// Fit within the pixel size and reply budget, or the reply fails with PayloadTooLarge.
// ImageIO's thumbnail decodes only the pixels of the size asked for, whatever the file's dimensions: decoding the
// whole image first (UIImage) took width × height × 4 bytes, about 1.6 GB for a 20000-pixel square cover from a
// hostile or broken server (security review M-07). The thumbnail keeps the file's orientation, as UIImage did, never
// enlarges, and keeps at least one pixel per side, so a very thin image can't ask for a zero-sized one.
private func resizedJPEG(_ source: CGImageSource, maxSide: CGFloat) -> Data? {
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let pixelWidth = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? maxSide
    let pixelHeight = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? maxSide
    var side = min(maxSide, max(pixelWidth, pixelHeight))
    // Try the requested size below 64 px too; only later reductions have that floor.
    repeat {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, side.rounded()),
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let resized = UIImage(cgImage: thumbnail)
        for quality in [0.9, 0.8, 0.7, 0.6, 0.5, 0.4] {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= artworksReplyBudget {
                return jpeg
            }
        }
        side *= 0.8
    } while side >= 64
    return nil
}
