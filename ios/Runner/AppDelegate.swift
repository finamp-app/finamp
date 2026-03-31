import app_links
import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    /// Retained chapter extraction channel — must be an instance var so it is
    /// not deallocated after setupChapterChannel() returns.
    @objc var chapterChannel: FlutterMethodChannel?

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
        setupChapterChannel(registry: engineBridge.pluginRegistry)
    }

    func setupChapterChannel(registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "ChapterExtractor") else {
            NSLog("[Chapters] setupChapterChannel skipped — could not get registrar")
            return
        }
        let messenger = registrar.messenger()
        NSLog("[Chapters] Creating MethodChannel on binaryMessenger")
        let channel = FlutterMethodChannel(
            name: "com.unicornsonlsd.finamp/chapters",
            binaryMessenger: messenger
        )
        chapterChannel = channel
        channel.setMethodCallHandler { (call, result) in
            guard call.method == "extractChapters",
                  let urlString = call.arguments as? String,
                  let url = URL(string: urlString) else {
                result(FlutterMethodNotImplemented)
                return
            }

            NSLog("[Chapters] Loading availableChapterLocales for URL: \(urlString)")
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false
            ])

            asset.loadValuesAsynchronously(forKeys: ["availableChapterLocales"]) {
                var loadError: NSError?
                let status = asset.statusOfValue(forKey: "availableChapterLocales", error: &loadError)
                guard status == .loaded else {
                    NSLog("[Chapters] Failed to load availableChapterLocales: status=\(status.rawValue) error=\(String(describing: loadError))")
                    DispatchQueue.main.async { result([]) }
                    return
                }

                let preferredLanguages = Locale.preferredLanguages + ["und", ""]
                NSLog("[Chapters] availableChapterLocales: \(asset.availableChapterLocales)")
                let groups = asset.chapterMetadataGroups(bestMatchingPreferredLanguages: preferredLanguages)
                NSLog("[Chapters] Found \(groups.count) chapter groups")

                var chapters: [[String: Any]] = []
                for group in groups {
                    let startMs = Int64(CMTimeGetSeconds(group.timeRange.start) * 1000)
                    // startPositionTicks = 100-nanosecond units (10^7 per second)
                    let ticks = startMs * 10000
                    var title = ""
                    for item in group.items {
                        if item.commonKey == AVMetadataKey.commonKeyTitle,
                           let t = item.value as? String {
                            title = t
                            break
                        }
                    }
                    chapters.append(["ticks": ticks, "name": title])
                }

                NSLog("[Chapters] Returning \(chapters.count) chapters")
                DispatchQueue.main.async { result(chapters) }
            }
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
