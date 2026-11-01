import AVKit
import Flutter
import UIKit
import WatchConnectivity

// Relays watch requests to Flutter's WatchHandler and forwards state updates to the watch.

private var watchChannel: FlutterMethodChannel?
private let watchBridge = WatchBridge()

extension AppDelegate {
    func setupWatchChannel() {
        // Must match WatchHandler even when a personal build changes the bundle id.
        watchChannel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp-ios/watch",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        watchChannel?.setMethodCallHandler { call, result in
            switch call.method {
            case "nowPlaying" where call.arguments is [String: Any],
                 "theme" where call.arguments is String,
                 "account" where call.arguments is String,
                 "transcoding" where call.arguments is Bool,
                 "offline" where call.arguments is Bool,
                 "volume" where call.arguments is Double,
                 "airPlay" where call.arguments is Bool:
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
    }

    /// Keep all keys: updateApplicationContext replaces the entire context.
    private var context: [String: Any] = [:]

    /// Sends live when reachable and saves the value for the watch's next launch.
    func push(key: String, value: Any) {
        guard WCSession.isSupported() else { return }
        // A different account's playback must not carry over to the next one
        if key == "account", context["account"] as? String != value as? String {
            context["nowPlaying"] = nil
        }
        context[key] = value
        let session = WCSession.default
        // Not gated on isWatchAppInstalled: iOS can report false for an installed watch app that is sending requests
        guard session.activationState == .activated, session.isPaired else { return }
        try? session.updateApplicationContext(context)
        if session.isReachable {
            session.sendMessage([key: value], replyHandler: nil, errorHandler: nil)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            NSLog("[FINAMP] Watch session activation failed: \(error)")
        }
        watchStateDidChange()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        watchStateDidChange()
    }

    var isWatchAppAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    /// The installed flag at the previous watch state change.
    private var wasInstalled = false

    /// Flushes state held before activation and tells Flutter to start pushing, or to stop once the watch app is gone.
    private func watchStateDidChange() {
        DispatchQueue.main.async { [self] in
            let session = WCSession.default
            let paired = session.activationState == .activated && session.isPaired
            let installed = isWatchAppAvailable
            // iOS can keep reporting false for an installed app, so only unpairing or a change to false means it's gone
            let removed = !paired || (wasInstalled && !installed)
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

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let method = message["method"] as? String else {
            replyHandler(["error": "Missing method"])
            return
        }

        // The output picker requires native iOS UI.
        if method == "showOutputPicker" {
            DispatchQueue.main.async {
                replyHandler(["result": outputPicker.show() ? "shown" : "pending"])
            }
            return
        }

        DispatchQueue.main.async {
            guard let channel = watchChannel else {
                replyHandler(["error": "Finamp is still starting"])
                return
            }
            channel.invokeMethod(method, arguments: message["args"]) { result in
                if let error = result as? FlutterError {
                    replyHandler(["error": error.message ?? error.code, "code": error.code])
                } else if (result as AnyObject?) === FlutterMethodNotImplemented {
                    replyHandler(["error": "Finamp is still starting"])
                } else if method == "artworks" {
                    replyHandler(artworksReply(result, request: message["args"]))
                } else if let result = result, !(result is NSNull) {
                    replyHandler(["result": result])
                } else {
                    replyHandler([:])
                }
            }
        }
    }
}

private let outputPicker = OutputPicker()

/// Presents the phone's output picker for watch requests.
/// iOS has no public presentation method, so tap a hidden AVRoutePickerView button.
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

    /// Returns true if shown; otherwise queues the request for up to two minutes.
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
        // The picker must stay in the window as the menu's invisible anchor.
        picker.frame = CGRect(x: window.bounds.midX - 1, y: window.safeAreaInsets.top + 40, width: 2, height: 2)
        picker.alpha = 0.011
        if picker.window !== window { window.addSubview(picker) }
        button.sendActions(for: .touchUpInside)
        return true
    }

    /// Remove the hidden picker after dismissal so it cannot intercept taps.
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

/// Leaves room for metadata within WatchConnectivity's roughly 64 KB message limit.
private let artworksReplyBudget = 48 * 1024

/// An image from Flutter's raw RGBA pixels (`ImageByteFormat.rawRgba`: 8 bits per channel, premultiplied alpha).
private func imageFromRGBA(_ pixels: Data, width: Int, height: Int) -> UIImage? {
    guard width > 0, height > 0, pixels.count >= width * height * 4,
          let provider = CGDataProvider(data: pixels as CFData),
          let cgImage = CGImage(
              width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
              provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
          ) else { return nil }
    return UIImage(cgImage: cgImage)
}

/// Returns JPEGs and missing keys as "<id>-<size>" so one item can have multiple sizes.
/// Budget-deferred covers appear in neither set; the watch retries them.
private func artworksReply(_ result: Any?, request: Any?) -> [String: Any] {
    let requested = ((request as? [String: Any])?["items"] as? [[String: Any]]) ?? []
    let results = (result as? [[String: Any]]) ?? []

    var artworks: [String: Data] = [:]
    var missing: [String] = []
    var bytes = 0
    for (item, entry) in zip(requested, results) {
        guard let id = item["id"] as? String, let size = item["size"] as? Int else { continue }
        let key = "\(id)-\(size)"
        // The same bounds as the Flutter side, which only checks the size it decodes at
        guard (16...1200).contains(size) else {
            missing.append(key)
            continue
        }
        // A downloaded cover comes as its encoded file (no width), others as raw pixels
        let width = entry["width"] as? Int ?? 0
        let data = (entry["data"] as? FlutterStandardTypedData)?.data
        let image = data.flatMap { width > 0 ? imageFromRGBA($0, width: width, height: entry["height"] as? Int ?? 0) : UIImage(data: $0) }
        guard let image, let jpeg = resizedJPEG(image, maxSide: CGFloat(size)) else {
            missing.append(key)
            continue
        }
        if bytes + jpeg.count > artworksReplyBudget && !artworks.isEmpty { continue }
        artworks[key] = jpeg
        bytes += jpeg.count
    }
    return ["artworks": artworks, "missing": missing]
}

/// Fits JPEGs within the pixel size and reply budget to avoid PayloadTooLarge errors.
private func resizedJPEG(_ image: UIImage, maxSide: CGFloat) -> Data? {
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    var side = min(maxSide, max(pixelWidth, pixelHeight))
    // Try the requested size even below 64 px; 64 px only limits subsequent reductions.
    repeat {
        let factor = side / max(pixelWidth, pixelHeight)
        let targetSize = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        for quality in [0.9, 0.8, 0.7, 0.6, 0.5, 0.4] {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= artworksReplyBudget {
                return jpeg
            }
        }
        side *= 0.8
    } while side >= 64
    return nil
}
