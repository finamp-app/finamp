import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Prevents startup autoplay from waking someone when Android restarts the
/// app while the device is still locked.
class AndroidStartupAutoplayGuard {
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/android_startup');
  static final _logger = Logger('AndroidStartupAutoplayGuard');

  /// Returns whether an automatic queue restore may begin playback for the
  /// current Android lock state.
  static bool mayAutoplayWhileKeyguardLocked(bool isKeyguardLocked) => !isKeyguardLocked;

  /// Returns whether the automatic queue restore that happens during app
  /// startup may begin playing.
  ///
  /// Non-Android platforms keep their current behavior. On Android, failure
  /// to read the keyguard state is handled conservatively by leaving the queue
  /// paused rather than unexpectedly starting audio in the background.
  static Future<bool> mayAutoplayInitialQueue() async {
    if (!Platform.isAndroid) return true;

    try {
      final isKeyguardLocked = await _channel.invokeMethod<bool>('getIsKeyguardLocked');
      if (isKeyguardLocked == null) {
        _logger.warning('Could not determine Android keyguard state; suppressing startup autoplay');
        return false;
      }

      final mayAutoplay = mayAutoplayWhileKeyguardLocked(isKeyguardLocked);
      if (!mayAutoplay) {
        _logger.info('Suppressing startup autoplay: Android keyguard is locked');
      }
      return mayAutoplay;
    } catch (e) {
      _logger.warning('Could not determine Android keyguard state; suppressing startup autoplay: $e');
      return false;
    }
  }
}
