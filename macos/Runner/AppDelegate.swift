import app_links
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        // Only terminate if the window was actually closed, not hidden to the system tray (orderOut).
        return !sender.windows.contains { $0 is MainFlutterWindow }
    }

    override func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            for window in sender.windows where window is MainFlutterWindow {
                window.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }

    public override func application(
        _ application: NSApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        guard let url = AppLinks.shared.getUniversalLink(userActivity) else {
            return false
        }

        AppLinks.shared.handleLink(link: url.absoluteString)

        return false  // Returning true will stop the propagation to other packages
    }
}
