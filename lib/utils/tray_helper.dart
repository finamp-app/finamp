import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

Future<void> hideToTray() async {
  await windowManager.hide();
  if (Platform.isMacOS) {
    // This will prevents the window from appearing in the taskbar
    // which apparently crashes on Windows
    await windowManager.setSkipTaskbar(true);
  }
}

Future<void> showFromTray() async {
  await windowManager.show();
  await windowManager.focus();
  if (Platform.isMacOS) {
    await windowManager.setSkipTaskbar(false);
  }
}

Future<void> destroyTray() async {
  if (Platform.isLinux) {
    await trayManager.destroy();
  }
}
