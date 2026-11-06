import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  private var startHidden = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let windowChannel = FlutterMethodChannel(
      name: "finamp/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setStartHidden":
        if let value = call.arguments as? Bool {
          self?.startHidden = value
        }
        result(nil)
      case "showIfNotStartHidden":
        if let self = self, !self.startHidden {
          self.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
