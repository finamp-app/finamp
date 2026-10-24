import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var nowPlayingController: NowPlayingController?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    nowPlayingController = NowPlayingController(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
