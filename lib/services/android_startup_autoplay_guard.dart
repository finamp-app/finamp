import 'dart:io' show Platform;

import 'package:finamp_android_startup/finamp_android_startup.dart';
import 'package:logging/logging.dart';

/// Prevents startup autoplay from waking someone when Android restarts the
/// app while the device is still locked.
class AndroidStartupAutoplayGuard {
  static final _logger = Logger('AndroidStartupAutoplayGuard');
  static const _gracePeriod = Duration(minutes: 2);

  /// Returns the reason an Android startup restore must not begin playback.
  ///
  /// A real user-unlock event lets a restore proceed before the two-minute
  /// boot/update grace periods expire. The event is deliberately only a
  /// permission to autoplay, never a command that starts playback itself.
  static String? autoplaySuppressionReason(FinampAndroidStartupState state) {
    if (state.isKeyguardLocked) return 'Android keyguard is locked';
    if (state.uptime < _gracePeriod && !state.userPresentSinceBoot) {
      return 'device booted less than two minutes ago without a user-present event';
    }
    if (state.packageUpdateAge < _gracePeriod && !state.userPresentSinceUpdate) {
      return 'Finamp was updated less than two minutes ago without a user-present event';
    }
    return null;
  }

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
      final state = await FinampAndroidStartup.getStartupState();
      if (state == null) {
        _logger.warning('Could not determine Android startup state; suppressing startup autoplay');
        return false;
      }

      final reason = autoplaySuppressionReason(state);
      _logger.info(
        'Android startup autoplay state: keyguardLocked=${state.isKeyguardLocked}, '
        'uptime=${state.uptime.inSeconds}s, packageUpdateAge=${state.packageUpdateAge.inSeconds}s, '
        'userPresentSinceBoot=${state.userPresentSinceBoot}, '
        'userPresentSinceUpdate=${state.userPresentSinceUpdate}; '
        '${reason == null ? 'allowing startup autoplay' : 'suppressing startup autoplay: $reason'}',
      );
      return reason == null;
    } catch (e) {
      _logger.warning('Could not determine Android startup state; suppressing startup autoplay: $e');
      return false;
    }
  }
}
