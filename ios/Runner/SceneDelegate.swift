//
//  SceneDelegate.swift
//  Runner
//
//  Required by flutter_carplay plugin
//

import UIKit
import Flutter

@available(iOS 13.0, *)
@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // An extra window scene (iPadOS multi-window) is destroyed by the
        // AppDelegate right after connecting. Leave it blank rather than
        // letting it steal the single Flutter engine from the primary window.
        let hasOtherWindowScene = UIApplication.shared.connectedScenes.contains { $0 is UIWindowScene && $0 !== scene }
        if hasOtherWindowScene && flutterEngine.viewController != nil {
            return
        }

        window = UIWindow(windowScene: windowScene)

        let controller = FlutterViewController.init(engine: flutterEngine, nibName: nil, bundle: nil)
        controller.loadDefaultSplashScreenView()
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
    }
}
