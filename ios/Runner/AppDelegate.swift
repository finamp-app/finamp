import app_links
import UIKit
import Flutter
import MediaPlayer
import Intents

// Shared engine for CarPlay - the flutter_carplay plugin requires this
let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, INPlayMediaIntentHandling {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Start the shared engine and register plugins with it for CarPlay
        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: flutterEngine)

        // Set up method channel for playback state sync to MPNowPlayingInfoCenter
        // TODO: This is a workaround because audio_service doesn't set playbackState on iOS.
        // Consider contributing a fix to audio_service to set MPNowPlayingInfoCenter.playbackState on iOS.
        setupPlaybackStateChannel()

        // Set up method channel for Siri media intent handling
        setupSiriIntentChannel()

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
    }

    // Tell iOS to dispatch media intents to this AppDelegate (in-app intent handling, iOS 14+)
    override func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        if intent is INPlayMediaIntent {
            return self
        }
        return nil
    }

    // Required for scene-based lifecycle to properly configure CarPlay scene
    @available(iOS 13.0, *)
    override func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check if this is a CarPlay scene (CPTemplateApplicationSceneSessionRoleApplication)
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
            let sceneConfig = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            // Use the flutter_carplay plugin's delegate directly (now that it's @objc accessible)
            sceneConfig.delegateClass = NSClassFromString("flutter_carplay.FlutterCarPlaySceneDelegate")
            return sceneConfig
        }

        // For the main app window scene, return configuration with SceneDelegate
        let sceneConfig = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        sceneConfig.delegateClass = SceneDelegate.self
        sceneConfig.storyboard = UIStoryboard(name: "Main", bundle: nil)
        return sceneConfig
    }
}

private func setExcludeFromiCloudBackup(_ dir: URL, isExcluded: Bool) throws {
//    Awkwardly make a mutable copy of the dir
    var mutableDir = dir

    var values = URLResourceValues()
    values.isExcludedFromBackup = isExcluded
    try mutableDir.setResourceValues(values)
}

// MARK: - Playback State Sync for CarPlay
// TODO: This is a workaround because audio_service doesn't set MPNowPlayingInfoCenter.playbackState on iOS.
// The audio_service plugin only sets playbackState on macOS (see AudioServicePlugin.m line 293-295).
// This causes CarPlay's Now Playing screen to not reflect the correct play/pause state when
// playback is started from the phone. Consider contributing a fix upstream to audio_service.

extension AppDelegate {
    func setupPlaybackStateChannel() {
        let channel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp/playback_state",
            binaryMessenger: flutterEngine.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "setPlaybackState":
                guard let args = call.arguments as? [String: Any],
                      let isPlaying = args["isPlaying"] as? Bool else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing isPlaying argument", details: nil))
                    return
                }

                if #available(iOS 13.0, *) {
                    let center = MPNowPlayingInfoCenter.default()
                    center.playbackState = isPlaying ? .playing : .paused
                }
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

// MARK: - Siri Media Intent Handling
// Handles voice commands like "Hey Siri, play [song/artist] on Finamp"

private var siriIntentChannel: FlutterMethodChannel?

extension AppDelegate {
    func setupSiriIntentChannel() {
        siriIntentChannel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp/siri_intent",
            binaryMessenger: flutterEngine.binaryMessenger
        )
    }

    // MARK: INPlayMediaIntentHandling

    /// Resolves media items for Siri so it knows the app can handle the request.
    /// Without this, Siri says "That action is not supported on Finamp."
    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        // If Siri provided media items, accept them
        if let mediaItems = intent.mediaItems, !mediaItems.isEmpty {
            completion(mediaItems.map { INPlayMediaMediaItemResolutionResult.success(with: $0) })
            return
        }

        // Otherwise, create a media item from the search to tell Siri we can handle it
        let mediaSearch = intent.mediaSearch
        let title = mediaSearch?.mediaName ?? mediaSearch?.artistName ?? mediaSearch?.albumName ?? "Music"
        let mediaItem = INMediaItem(
            identifier: nil,
            title: title,
            type: .music,
            artwork: nil
        )
        completion([INPlayMediaMediaItemResolutionResult.success(with: mediaItem)])
    }

    /// Handles the play media intent from Siri by forwarding to Flutter.
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        let searchData = extractSearchData(from: intent)

        NSLog("[FINAMP] Siri handle play intent - query: \(searchData["query"] ?? "nil"), artist: \(searchData["artist"] ?? "nil"), album: \(searchData["album"] ?? "nil")")

        siriIntentChannel?.invokeMethod("playFromSearch", arguments: searchData)

        completion(INPlayMediaIntentResponse(code: .success, userActivity: nil))
    }

    /// Extracts search parameters from an INPlayMediaIntent into a dictionary for Flutter.
    private func extractSearchData(from intent: INPlayMediaIntent) -> [String: Any] {
        let mediaSearch = intent.mediaSearch
        var searchData: [String: Any] = [:]

        if let mediaName = mediaSearch?.mediaName {
            searchData["query"] = mediaName
        }
        if let artistName = mediaSearch?.artistName {
            searchData["artist"] = artistName
        }
        if let albumName = mediaSearch?.albumName {
            searchData["album"] = albumName
        }
        if let genreNames = mediaSearch?.genreNames, !genreNames.isEmpty {
            searchData["genre"] = genreNames.first
        }
        if intent.playShuffled == true {
            searchData["shuffle"] = true
        }

        return searchData
    }

    // MARK: NSUserActivity fallback

    // Handle Siri media intents via NSUserActivity (fallback path)
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Check if this is a Siri media intent
        if userActivity.activityType == NSStringFromClass(INPlayMediaIntent.self) ||
           userActivity.activityType == "INPlayMediaIntent" {
            return handlePlayMediaIntent(userActivity: userActivity)
        }

        if userActivity.activityType == NSStringFromClass(INSearchForMediaIntent.self) ||
           userActivity.activityType == "INSearchForMediaIntent" {
            return handleSearchForMediaIntent(userActivity: userActivity)
        }

        // Fall back to default handling (e.g., app links)
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    private func handlePlayMediaIntent(userActivity: NSUserActivity) -> Bool {
        guard let interaction = userActivity.interaction,
              let intent = interaction.intent as? INPlayMediaIntent else {
            NSLog("[FINAMP] Could not extract INPlayMediaIntent from user activity")
            return false
        }

        let searchData = extractSearchData(from: intent)

        NSLog("[FINAMP] Play media intent via NSUserActivity - query: \(searchData["query"] ?? "nil"), artist: \(searchData["artist"] ?? "nil"), album: \(searchData["album"] ?? "nil")")

        siriIntentChannel?.invokeMethod("playFromSearch", arguments: searchData)

        return true
    }

    private func handleSearchForMediaIntent(userActivity: NSUserActivity) -> Bool {
        guard let interaction = userActivity.interaction,
              let intent = interaction.intent as? INSearchForMediaIntent else {
            NSLog("[FINAMP] Could not extract INSearchForMediaIntent from user activity")
            return false
        }

        let mediaSearch = intent.mediaSearch
        var searchData: [String: Any] = [:]

        if let mediaName = mediaSearch?.mediaName {
            searchData["query"] = mediaName
        }
        if let artistName = mediaSearch?.artistName {
            searchData["artist"] = artistName
        }
        if let albumName = mediaSearch?.albumName {
            searchData["album"] = albumName
        }
        searchData["searchOnly"] = true

        NSLog("[FINAMP] Search media intent - query: \(searchData["query"] ?? "nil")")

        siriIntentChannel?.invokeMethod("searchMedia", arguments: searchData)

        return true
    }
}
