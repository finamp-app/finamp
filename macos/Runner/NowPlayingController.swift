import Cocoa
import FlutterMacOS
import ImageIO
import MediaPlayer

/// The main app process owns both metadata and transport commands.
final class NowPlayingController {
    private let channel: FlutterMethodChannel
    private let center = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()
    private var targets: [(MPRemoteCommand, Any)] = []
    private var snapshot: [String: Any]?
    private var artwork: MPMediaItemArtwork?
    private var artworkKey: String?
    private var artworkGeneration = 0
    private var publishedAt = ProcessInfo.processInfo.systemUptime

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp/now_playing", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "publish" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.publish(call.arguments as? [String: Any])
            result(nil)
        }
        install(commands.playCommand, method: "play")
        install(commands.pauseCommand, method: "pause")
        install(commands.togglePlayPauseCommand, method: "toggle")
        install(commands.nextTrackCommand, method: "next")
        install(commands.previousTrackCommand, method: "previous")
        let target = commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, self.snapshot?["canSeek"] as? Bool == true,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  event.positionTime.isFinite, event.positionTime >= 0 else {
                return .commandFailed
            }
            self.send("seek", arguments: event.positionTime)
            return .success
        }
        targets.append((commands.changePlaybackPositionCommand, target))
        publish(nil)
    }

    private func install(_ command: MPRemoteCommand, method: String) {
        let target = command.addTarget { [weak self, weak command] _ in
            guard let self, self.snapshot != nil, command?.isEnabled == true else {
                return .noSuchContent
            }
            self.send(method)
            return .success
        }
        targets.append((command, target))
    }

    private func send(_ method: String, arguments: Any? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod(method, arguments: arguments)
        }
    }

    func publish(_ value: [String: Any]?) {
        snapshot = value
        let canPlay = value?["canPlay"] as? Bool == true
        commands.playCommand.isEnabled = canPlay
        commands.pauseCommand.isEnabled = canPlay
        commands.togglePlayPauseCommand.isEnabled = canPlay
        commands.nextTrackCommand.isEnabled = value?["canNext"] as? Bool == true
        commands.previousTrackCommand.isEnabled = value?["canPrevious"] as? Bool == true
        commands.changePlaybackPositionCommand.isEnabled = value?["canSeek"] as? Bool == true
        commands.stopCommand.isEnabled = false
        commands.changePlaybackRateCommand.isEnabled = false
        commands.skipForwardCommand.isEnabled = false
        commands.skipBackwardCommand.isEnabled = false
        commands.seekForwardCommand.isEnabled = false
        commands.seekBackwardCommand.isEnabled = false

        let path = value?["artPath"] as? String
        let key = path.map { "\(value?["id"] as? String ?? ""):\($0)" }
        if key != artworkKey || value == nil {
            artworkGeneration += 1
            artworkKey = key
            artwork = nil
            if let path {
                loadArtwork(path: path, generation: artworkGeneration)
            }
        }
        updateCenter()
    }

    private func updateCenter() {
        guard let snapshot else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info = Self.metadata(snapshot)
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        center.nowPlayingInfo = info
        publishedAt = ProcessInfo.processInfo.systemUptime
        switch snapshot["state"] as? String {
        case "playing": center.playbackState = .playing
        case "paused": center.playbackState = .paused
        default: center.playbackState = .stopped
        }
    }

    /// Pure mapping kept separate so malformed values can be regression tested.
    static func metadata(_ value: [String: Any]) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: value["title"] as? String ?? "",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        for (input, output) in [
            "id": MPNowPlayingInfoPropertyExternalContentIdentifier,
            "artist": MPMediaItemPropertyArtist,
            "album": MPMediaItemPropertyAlbumTitle,
        ] {
            if let text = value[input] as? String, !text.isEmpty { info[output] = text }
        }
        if let duration = value["duration"] as? Double, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        let elapsed = value["elapsed"] as? Double ?? 0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed.isFinite ? max(0, elapsed) : 0.0
        let rate = value["rate"] as? Double ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] =
            value["state"] as? String == "playing" && rate.isFinite ? max(0, rate) : 0.0
        return info
    }

    private func loadArtwork(path: String, generation: Int) {
        // Decode a bounded thumbnail off the UI thread, then reject stale work.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
            ]
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
            let image = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.artworkGeneration == generation, let image else { return }
                let art = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                self.artwork = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
                // Re-anchor progress: assigning the dictionary resets the system timestamp.
                var info = self.center.nowPlayingInfo ?? [:]
                let now = ProcessInfo.processInfo.systemUptime
                let elapsed = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0
                let rate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed + (now - self.publishedAt) * rate
                info[MPMediaItemPropertyArtwork] = self.artwork
                self.center.nowPlayingInfo = info
                self.publishedAt = now
            }
        }
    }

    deinit {
        for (command, target) in targets { command.removeTarget(target) }
        channel.setMethodCallHandler(nil)
        center.nowPlayingInfo = nil
        center.playbackState = .stopped
    }
}
