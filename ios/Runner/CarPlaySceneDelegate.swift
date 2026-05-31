//
//  CarPlaySceneDelegate.swift
//  Runner
//
//  CarPlay scene delegate for Finamp - reproduces flutter_carplay plugin delegate logic
//

import UIKit
import CarPlay
import Flutter

// Need to replicate the plugin's channel constants
private let FCPChannelId = "flutter_carplay"
private func makeFCPChannelId(event: String) -> String {
    return "\(FCPChannelId)/\(event)"
}

@available(iOS 14.0, *)
@objc(CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPInterfaceControllerDelegate {

    private static var interfaceController: CPInterfaceController?

    override init() {
        super.init()
        NSLog("[FINAMP-CarPlay] CarPlaySceneDelegate initialized")
    }

    @objc(templateApplicationScene:didConnectInterfaceController:)
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        NSLog("[FINAMP-CarPlay] didConnect interfaceController")

        CarPlaySceneDelegate.interfaceController = interfaceController
        interfaceController.delegate = self

        // Send connection event to Flutter using the plugin's event channel
        let eventChannel = FlutterEventChannel(
            name: makeFCPChannelId(event: "onCarplayConnectionChange"),
            binaryMessenger: flutterEngine.binaryMessenger
        )

        // Also try method channel approach
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )

        // Notify Flutter that CarPlay connected
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "connected"])

        NSLog("[FINAMP-CarPlay] CarPlay connected successfully - notified Flutter")
    }

    @objc(templateApplicationScene:didDisconnectInterfaceController:)
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        NSLog("[FINAMP-CarPlay] didDisconnectInterfaceController")

        // Notify Flutter of disconnection
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "disconnected"])

        interfaceController.delegate = nil
        CarPlaySceneDelegate.interfaceController = nil

        NSLog("[FINAMP-CarPlay] CarPlay disconnected")
    }

    // Scene lifecycle events
    func sceneDidBecomeActive(_ scene: UIScene) {
        NSLog("[FINAMP-CarPlay] sceneDidBecomeActive")
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "connected"])
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NSLog("[FINAMP-CarPlay] sceneDidEnterBackground")
        let methodChannel = FlutterMethodChannel(
            name: makeFCPChannelId(event: ""),
            binaryMessenger: flutterEngine.binaryMessenger
        )
        methodChannel.invokeMethod("onCarplayConnectionChange", arguments: ["status": "background"])
    }

    // CPInterfaceControllerDelegate method
    func templateDidDisappear(_ template: CPTemplate, animated: Bool) {
        NSLog("[FINAMP-CarPlay] templateDidDisappear")
    }
}
