import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Prevents startup autoplay from waking someone while Android is still
/// completing a device reboot or system update.
class AndroidStartupAutoplayGuard {
  static const startupGracePeriod = Duration(minutes: 3);
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/android_startup');
  static final _logger = Logger('AndroidStartupAutoplayGuard');

  /// Returns whether [uptime] has passed the period where startup autoplay is
  /// suppressed after an Android device boot.
  static bool hasCompletedStartupGracePeriod(Duration uptime) => uptime >= startupGracePeriod;

  /// Returns whether the automatic queue restore that happens during app
  /// startup may begin playing.
  ///
  /// Non-Android platforms keep their current behavior. On Android, failure
  /// to read the device uptime is handled conservatively by leaving the queue
  /// paused rather than unexpectedly starting audio after a reboot.
  static Future<bool> mayAutoplayInitialQueue() async {
    if (!Platform.isAndroid) return true;

    try {
      final elapsedRealtimeMillis = await _channel.invokeMethod<int>('getElapsedRealtimeMillis');
      if (elapsedRealtimeMillis == null) {
        _logger.warning('Could not determine Android device uptime; suppressing startup autoplay');
        return false;
      }

      final uptime = Duration(milliseconds: elapsedRealtimeMillis);
      final mayAutoplay = hasCompletedStartupGracePeriod(uptime);
      if (!mayAutoplay) {
        _logger.info('Suppressing startup autoplay: Android device uptime is $uptime');
      }
      return mayAutoplay;
    } catch (e) {
      _logger.warning('Could not determine Android device uptime; suppressing startup autoplay: $e');
      return false;
    }
  }
}
