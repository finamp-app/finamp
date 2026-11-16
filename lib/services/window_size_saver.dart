import 'dart:async';
import 'dart:ui';

import 'package:finamp/models/finamp_models.dart';
import 'package:logging/logging.dart';

/// Persists the desktop window bounds while the user moves or resizes it.
///
/// window_manager emits "moved"/"resized" once the interaction has finished on
/// macOS and Windows, but only "move"/"resize" while the window is being
/// dragged on Linux. Those high-frequency events are debounced so the settings
/// are not written to Hive on every GTK event.
class WindowSizeSaver {
  WindowSizeSaver({
    required Future<Rect> Function() getBounds,
    required void Function(ScreenSize) saveScreenSize,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : _getBounds = getBounds,
       _saveScreenSize = saveScreenSize;

  static final Logger _logger = Logger("WindowManager");

  final Future<Rect> Function() _getBounds;
  final void Function(ScreenSize) _saveScreenSize;
  final Duration debounceDuration;

  Timer? _debounceTimer;

  void onWindowEvent(String eventName) {
    if (eventName == "moved" || eventName == "resized") {
      _debounceTimer?.cancel();
      unawaited(_save());
    } else if (eventName == "move" || eventName == "resize") {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () => unawaited(_save()));
    }
  }

  /// Saves the current bounds before the window goes away.
  ///
  /// The bounds are only queried while the window still exists. On Linux, a
  /// close that is not intercepted destroys the GTK window immediately, and
  /// querying its bounds afterwards returns unreliable values.
  Future<void> onWindowClose({required bool isPreventClose}) async {
    _debounceTimer?.cancel();
    if (!isPreventClose) {
      return;
    }
    await _save();
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  Future<void> _save() async {
    try {
      final bounds = await _getBounds();
      _saveScreenSize(ScreenSize.from(bounds));
      _logger.finer("Saved window size and position");
    } catch (e) {
      _logger.warning("Failed to save window size and position: $e");
    }
  }
}
