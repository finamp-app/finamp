//
//  SceneDelegate.swift
//  Runner
//
//  Flutter UIScene lifecycle. Subclasses FlutterSceneDelegate so we can ignore
//  empty NSUserActivity types (iOS can abort when activityType is blank —
//  seen with keyboard autofill during tsnet interactive login). Info.plist must
//  also declare NSUserActivityTypes (Debug/Profile/Release).
//

import Flutter
import UIKit

@available(iOS 13.0, *)
@objc(SceneDelegate)
class SceneDelegate: FlutterSceneDelegate {
  open override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard !userActivity.activityType.isEmpty else {
      NSLog("[FINAMP] Ignoring NSUserActivity with empty activityType")
      return
    }
    super.scene(scene, continue: userActivity)
  }
}
