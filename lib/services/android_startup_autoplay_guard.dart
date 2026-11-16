import 'dart:io' show Platform;

import 'package:finamp_android_startup/finamp_android_startup.dart';
import 'package:logging/logging.dart';

/// Prevents startup autoplay from waking someone when Android restarts the
/// app while the device is still locked.
class AndroidStartupAutoplayGuard {
  static final _logger = Logger('AndroidStartupAutoplayGuard');

  /// Returns whether an automatic queue restore may begin playback for the
  /// Android lock state captured when startup restoration begins.
  static bool mayAutoplayWhileKeyguardLocked(bool isKeyguardLocked) => !isKeyguardLocked;

  /// Captures whether the automatic queue restore that happens during app
  /// startup may begin playing.
  ///
  /// Non-Android platforms keep their current behavior. On Android, failure
  /// to read the keyguard state is handled conservatively by leaving the queue
  /// paused rather than unexpectedly starting audio in the background. The
  /// caller retains this snapshot for the whole restore, so locking the screen
  /// after a restore has begun does not alter the requested playback behavior.
  static Future<bool> mayAutoplayInitialQueue() async {
    if (!Platform.isAndroid) return true;

    try {
      final isKeyguardLocked = await FinampAndroidStartup.isKeyguardLocked();
      if (isKeyguardLocked == null) {
        _logger.warning('Could not determine Android keyguard state; suppressing startup autoplay');
        return false;
      }

      final mayAutoplay = mayAutoplayWhileKeyguardLocked(isKeyguardLocked);
      _logger.info(
        mayAutoplay
            ? 'Allowing startup autoplay: Android keyguard is unlocked'
            : 'Suppressing startup autoplay: Android keyguard is locked',
      );
      return mayAutoplay;
    } catch (e) {
      _logger.warning('Could not determine Android keyguard state; suppressing startup autoplay: $e');
      return false;
    }
  }
}
