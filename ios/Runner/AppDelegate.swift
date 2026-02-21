import app_links
import CarPlay
import MediaPlayer
import UIKit
import Flutter
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Exclude the documents and support folders from iCloud backup since we keep songs there.
        if let documentsDir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            try? setExcludeFromiCloudBackup(documentsDir, isExcluded: true)
        }
        
        if let appSupportDir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            try? setExcludeFromiCloudBackup(appSupportDir, isExcluded: true)
        }
        
        // Retrieve the link from parameters
        if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
            // We have a link, propagate it to your Flutter app or not
            AppLinks.shared.handleLink(url: url)
            return true  // Returning true will stop the propagation to other packages
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        if #available(iOS 14.0, *) {
            CarPlayFlutterBridge.shared.configure(with: engineBridge.pluginRegistry)
        }
    }
}

private func setExcludeFromiCloudBackup(_ dir: URL, isExcluded: Bool) throws {
//    Awkwardly make a mutable copy of the dir
    var mutableDir = dir
    
    var values = URLResourceValues()
    values.isExcludedFromBackup = isExcluded
    try mutableDir.setResourceValues(values)
}

@available(iOS 14.0, *)
@objc(CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let logger = Logger(subsystem: "com.unicornsonlsd.finamp-ios", category: "CarPlay")

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        connect(interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        connect(interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        disconnect()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        disconnect()
    }

    private func connect(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        logger.info("CarPlay scene connected")
        interfaceController.setRootTemplate(makeLoadingTemplate(), animated: false, completion: nil)
        loadRootItems()
    }

    private func disconnect() {
        logger.info("CarPlay scene disconnected")
        self.interfaceController = nil
    }

    private func makeLoadingTemplate() -> CPTemplate {
        let localized = CarPlayFlutterBridge.shared.localizedStrings
        let item = CPListItem(text: localized.loadingTitle, detailText: localized.loadingSubtitle)
        item.isPlaying = false
        let section = CPListSection(items: [item], header: localized.appName, sectionIndexTitle: nil)
        return CPListTemplate(title: localized.appName, sections: [section])
    }

    private func makeErrorTemplate(_ message: String) -> CPTemplate {
        let localized = CarPlayFlutterBridge.shared.localizedStrings
        let retry = CPListItem(text: localized.retry, detailText: nil)
        retry.handler = { [weak self] _, completion in
            self?.interfaceController?.setRootTemplate(self?.makeLoadingTemplate() ?? CPNowPlayingTemplate.shared, animated: false, completion: nil)
            self?.loadRootItems()
            completion()
        }
        let info = CPListItem(text: localized.couldNotLoadLibrary, detailText: message)
        let section = CPListSection(items: [info, retry], header: localized.appName, sectionIndexTitle: nil)
        return CPListTemplate(title: localized.appName, sections: [section])
    }

    private func loadRootItems() {
        CarPlayFlutterBridge.shared.getRootItems { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    let localized = CarPlayFlutterBridge.shared.localizedStrings
                    self.interfaceController?.setRootTemplate(
                        self.makeListTemplate(title: localized.appName, items: items),
                        animated: false,
                        completion: nil
                    )
                case .failure(let error):
                    self.logger.error("Failed to load root items: \(error.localizedDescription, privacy: .public)")
                    self.interfaceController?.setRootTemplate(
                        self.makeErrorTemplate(error.localizedDescription),
                        animated: false,
                        completion: nil
                    )
                }
            }
        }
    }

    private func loadChildren(for item: CarPlayMediaItem) {
        CarPlayFlutterBridge.shared.getChildren(parentMediaId: item.id) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let children):
                    let childTemplate = self.makeListTemplate(title: item.title, items: children)
                    self.interfaceController?.pushTemplate(childTemplate, animated: true, completion: nil)
                case .failure(let error):
                    self.logger.error("Failed to load children: \(error.localizedDescription, privacy: .public)")
                    let localized = CarPlayFlutterBridge.shared.localizedStrings
                    let alert = CPAlertTemplate(
                        titleVariants: [localized.couldNotOpenItem(item.title)],
                        actions: [
                            CPAlertAction(title: localized.ok, style: .default, handler: { _ in }),
                        ]
                    )
                    self.interfaceController?.presentTemplate(alert, animated: true, completion: nil)
                }
            }
        }
    }

    private func makeListTemplate(title: String, items: [CarPlayMediaItem]) -> CPListTemplate {
        let carPlayItems = items.map { item in
            let listItem = CPListItem(text: item.title, detailText: item.subtitle)
            listItem.handler = { [weak self] _, completion in
                guard let self else {
                    completion()
                    return
                }
                if item.playable {
                    CarPlayFlutterBridge.shared.play(mediaId: item.id) { result in
                        DispatchQueue.main.async {
                            if case .failure(let error) = result {
                                self.logger.error("Failed to play media id \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                let localized = CarPlayFlutterBridge.shared.localizedStrings
                                let alert = CPAlertTemplate(
                                    titleVariants: [localized.playbackFailed],
                                    actions: [CPAlertAction(title: localized.ok, style: .default, handler: { _ in })]
                                )
                                self.interfaceController?.presentTemplate(alert, animated: true, completion: nil)
                            } else {
                                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                            }
                        }
                    }
                } else {
                    self.loadChildren(for: item)
                }
                completion()
            }
            return listItem
        }

        let localized = CarPlayFlutterBridge.shared.localizedStrings
        let nowPlayingItem = CPListItem(text: localized.nowPlaying, detailText: localized.openPlayerControls)
        nowPlayingItem.handler = { [weak self] _, completion in
            self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }

        let section = CPListSection(items: carPlayItems + [nowPlayingItem], header: nil, sectionIndexTitle: nil)
        return CPListTemplate(title: title, sections: [section])
    }
}

@available(iOS 14.0, *)
private struct CarPlayMediaItem {
    let id: String
    let title: String
    let subtitle: String?
    let playable: Bool

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String, let title = dict["title"] as? String else {
            return nil
        }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String
        self.playable = dict["playable"] as? Bool ?? false
    }
}

@available(iOS 14.0, *)
private final class CarPlayFlutterBridge {
    static let shared = CarPlayFlutterBridge()

    private var channel: FlutterMethodChannel?
    private let logger = Logger(subsystem: "com.unicornsonlsd.finamp-ios", category: "CarPlayBridge")
    private(set) var localizedStrings = CarPlayLocalizedStrings()

    private init() {}

    func configure(with pluginRegistry: FlutterPluginRegistry) {
        guard let registrar = pluginRegistry.registrar(forPlugin: "FinampCarPlayBridge") else {
            logger.error("Failed to get plugin registrar for CarPlay bridge")
            return
        }
        channel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp/carplay",
            binaryMessenger: registrar.messenger()
        )
        channel?.setMethodCallHandler({ [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        })
        logger.info("Configured Flutter bridge")
    }

    func getRootItems(completion: @escaping (Result<[CarPlayMediaItem], Error>) -> Void) {
        guard let channel else {
            completion(.failure(CarPlayBridgeError.notConfigured))
            return
        }

        channel.invokeMethod("getRootItems", arguments: nil) { result in
            completion(self.parseItems(result: result))
        }
    }

    func getChildren(parentMediaId: String, completion: @escaping (Result<[CarPlayMediaItem], Error>) -> Void) {
        guard let channel else {
            completion(.failure(CarPlayBridgeError.notConfigured))
            return
        }

        channel.invokeMethod("getChildren", arguments: ["parentMediaId": parentMediaId]) { result in
            completion(self.parseItems(result: result))
        }
    }

    func play(mediaId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let channel else {
            completion(.failure(CarPlayBridgeError.notConfigured))
            return
        }

        channel.invokeMethod("playFromMediaId", arguments: ["mediaId": mediaId]) { result in
            if let flutterError = result as? FlutterError {
                completion(.failure(CarPlayBridgeError.flutter(flutterError.message ?? "Unknown Flutter error")))
                return
            }
            completion(.success(()))
        }
    }

    private func parseItems(result: Any?) -> Result<[CarPlayMediaItem], Error> {
        if let flutterError = result as? FlutterError {
            return .failure(CarPlayBridgeError.flutter(flutterError.message ?? "Unknown Flutter error"))
        }

        guard let rows = result as? [Any] else {
            return .failure(CarPlayBridgeError.invalidResponse)
        }

        let items = rows.compactMap { row -> CarPlayMediaItem? in
            if let dict = row as? [String: Any] {
                return CarPlayMediaItem(dict: dict)
            }
            if let dict = row as? [AnyHashable: Any] {
                let mapped = dict.reduce(into: [String: Any]()) { partialResult, element in
                    partialResult[String(describing: element.key)] = element.value
                }
                return CarPlayMediaItem(dict: mapped)
            }
            return nil
        }

        return .success(items)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setLocalizedStrings":
            setLocalizedStrings(arguments: call.arguments)
            result(nil)
        case "syncNowPlayingState":
            syncNowPlayingState(arguments: call.arguments)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setLocalizedStrings(arguments: Any?) {
        guard let payload = arguments as? [String: Any] else {
            logger.error("setLocalizedStrings received invalid payload")
            return
        }
        localizedStrings.merge(payload)
    }

    private func syncNowPlayingState(arguments: Any?) {
        guard let payload = arguments as? [String: Any] else {
            logger.error("syncNowPlayingState received invalid payload")
            return
        }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

        set(info: &info, key: MPMediaItemPropertyTitle, value: payload["title"] as? String)
        set(info: &info, key: MPMediaItemPropertyArtist, value: payload["artist"] as? String)
        set(info: &info, key: MPMediaItemPropertyAlbumTitle, value: payload["album"] as? String)

        if let durationMs = payload["durationMs"] as? Int {
            info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        } else {
            info.removeValue(forKey: MPMediaItemPropertyPlaybackDuration)
        }

        let positionMs = payload["positionMs"] as? Int ?? 0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(positionMs) / 1000.0

        let playing = payload["playing"] as? Bool ?? false
        let speed = payload["speed"] as? Double ?? 1.0
        let rate = playing ? speed : 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = rate
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        if #available(iOS 13.0, *) {
            center.playbackState = playing ? .playing : .paused
        }
    }

    private func set(info: inout [String: Any], key: String, value: String?) {
        if let value, !value.isEmpty {
            info[key] = value
        } else {
            info.removeValue(forKey: key)
        }
    }
}

@available(iOS 14.0, *)
private enum CarPlayBridgeError: LocalizedError {
    case notConfigured
    case invalidResponse
    case flutter(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "CarPlay Flutter bridge is not configured."
        case .invalidResponse:
            return "CarPlay received an invalid response from Flutter."
        case .flutter(let message):
            return message
        }
    }
}

@available(iOS 14.0, *)
private struct CarPlayLocalizedStrings {
    var appName = "Finamp"
    var loadingTitle = "Loading…"
    var loadingSubtitle = "Fetching your library."
    var retry = "Retry"
    var couldNotLoadLibrary = "Could not load library"
    var couldNotOpenItemTemplate = "Could not open {itemTitle}"
    var playbackFailed = "Playback failed"
    var nowPlaying = "Now Playing"
    var openPlayerControls = "Open player controls."
    var ok = "OK"

    mutating func merge(_ payload: [String: Any]) {
        set(&appName, from: payload, key: "appName")
        set(&loadingTitle, from: payload, key: "loadingTitle")
        set(&loadingSubtitle, from: payload, key: "loadingSubtitle")
        set(&retry, from: payload, key: "retry")
        set(&couldNotLoadLibrary, from: payload, key: "couldNotLoadLibrary")
        set(&couldNotOpenItemTemplate, from: payload, key: "couldNotOpenItemTemplate")
        set(&playbackFailed, from: payload, key: "playbackFailed")
        set(&nowPlaying, from: payload, key: "nowPlaying")
        set(&openPlayerControls, from: payload, key: "openPlayerControls")
        set(&ok, from: payload, key: "ok")
    }

    func couldNotOpenItem(_ title: String) -> String {
        couldNotOpenItemTemplate.replacingOccurrences(of: "{itemTitle}", with: title)
    }

    private func set(_ target: inout String, from payload: [String: Any], key: String) {
        if let value = payload[key] as? String, !value.isEmpty {
            target = value
        }
    }
}
