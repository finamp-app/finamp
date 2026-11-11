import AVKit
import Flutter
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
                 "theme" where call.arguments is String,
                 "accent" where call.arguments is Int,
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

    // updateApplicationContext replaces entire context; keep all keys.
    private var context: [String: Any] = [:]

    func push(key: String, value: Any) {
        guard WCSession.isSupported() else { return }
        // Clear playback on account change.
        if key == "account", context["account"] as? String != value as? String {
            context["nowPlaying"] = nil
        }
        context[key] = value
        let session = WCSession.default
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

    private var wasInstalled = false

    private func watchStateDidChange() {
        DispatchQueue.main.async { [self] in
            let session = WCSession.default
            let paired = session.activationState == .activated && session.isPaired
            let installed = isWatchAppAvailable
            // iOS can report false for an installed app; only unpairing or a false transition means removed.
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

// Budget below WatchConnectivity's ~64 KB reply limit.
private let artworksReplyBudget = 48 * 1024

// Flutter rawRgba uses premultiplied alpha.
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
        // Reject out-of-range sizes; Dart clamps its decode size instead.
        guard (16...1200).contains(size) else {
            missing.append(key)
            continue
        }
        // Downloaded covers arrive encoded; others as raw pixels.
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

// Fit within the pixel size and reply budget, or the reply fails with PayloadTooLarge.
private func resizedJPEG(_ image: UIImage, maxSide: CGFloat) -> Data? {
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    var side = min(maxSide, max(pixelWidth, pixelHeight))
    // Try the requested size below 64 px too; only later reductions have that floor.
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
