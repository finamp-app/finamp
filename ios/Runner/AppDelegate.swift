import app_links
import UIKit
import Flutter

// Shared engine for CarPlay - the flutter_carplay plugin requires this
let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Start the shared engine and register plugins with it for CarPlay
        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: flutterEngine)

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

    // Required for scene-based lifecycle to properly configure CarPlay scene
    @available(iOS 13.0, *)
    override func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        NSLog("[FINAMP] Scene configuration requested for role: \(connectingSceneSession.role.rawValue)")

        // Check if this is a CarPlay scene (CPTemplateApplicationSceneSessionRoleApplication)
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
            NSLog("[FINAMP] Configuring CarPlay scene")
            let sceneConfig = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            // Use the flutter_carplay plugin's delegate directly (now that it's @objc accessible)
            let delegateClass = NSClassFromString("flutter_carplay.FlutterCarPlaySceneDelegate")
            NSLog("[FINAMP] CarPlay delegate class: \(String(describing: delegateClass))")
            sceneConfig.delegateClass = delegateClass
            return sceneConfig
        }

        NSLog("[FINAMP] Configuring default window scene")
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
