import Cocoa
import FlutterMacOS
import AVKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register the native AirPlay route picker platform view. The pub package
    // `flutter_to_airplay` only ships an iOS implementation, so the macOS view
    // is provided here directly against AppKit's AVRoutePickerView.
    let registrar = flutterViewController.registrar(forPlugin: "AirPlayRoutePickerView")
    registrar.register(
      AirPlayRoutePickerViewFactory(messenger: registrar.messenger),
      withId: "airplay_route_picker_view")

    super.awakeFromNib()
  }
}

/// Factory for the macOS AirPlay route picker platform view. Mirrors the view
/// type id used by the iOS plugin so the Dart side can share a single widget.
class AirPlayRoutePickerViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    return AirPlayRoutePickerPlatformView(
      viewId: viewId,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

/// Wraps AppKit's `AVRoutePickerView` so it can be embedded in the Flutter
/// widget tree on macOS. Colors and the delegate callbacks match the iOS
/// plugin's contract so `output_menu.dart` can treat both platforms the same.
class AirPlayRoutePickerPlatformView: NSView, AVRoutePickerViewDelegate {
  private let picker: AVRoutePickerView
  private let methodChannel: FlutterMethodChannel

  init(viewId: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
    picker = AVRoutePickerView(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
    methodChannel = FlutterMethodChannel(
      name: "flutter_to_airplay#\(viewId)", binaryMessenger: messenger)
    super.init(frame: NSRect(x: 0, y: 0, width: 44, height: 44))

    // Match the borderless, tinted look of the iOS picker button.
    picker.isRoutePickerButtonBordered = false

    if let tint = arguments["tintColor"] as? [String: Any],
      let color = AirPlayRoutePickerPlatformView.color(from: tint) {
      picker.setRoutePickerButtonColor(color, for: .normal)
    }
    if let activeTint = arguments["activeTintColor"] as? [String: Any],
      let color = AirPlayRoutePickerPlatformView.color(from: activeTint) {
      picker.setRoutePickerButtonColor(color, for: .active)
    }

    picker.delegate = self
    picker.translatesAutoresizingMaskIntoConstraints = false
    addSubview(picker)
    NSLayoutConstraint.activate([
      picker.leadingAnchor.constraint(equalTo: leadingAnchor),
      picker.trailingAnchor.constraint(equalTo: trailingAnchor),
      picker.topAnchor.constraint(equalTo: topAnchor),
      picker.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  static func color(from map: [String: Any]) -> NSColor? {
    guard let red = map["red"] as? NSNumber,
      let green = map["green"] as? NSNumber,
      let blue = map["blue"] as? NSNumber,
      let alpha = map["alpha"] as? NSNumber
    else {
      return nil
    }
    return NSColor(
      red: CGFloat(truncating: red),
      green: CGFloat(truncating: green),
      blue: CGFloat(truncating: blue),
      alpha: CGFloat(truncating: alpha))
  }

  func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
    methodChannel.invokeMethod("onShowPickerView", arguments: nil)
  }

  func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
    methodChannel.invokeMethod("onClosePickerView", arguments: nil)
  }
}
