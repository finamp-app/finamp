import 'package:flutter/services.dart';

/// Android startup state, available even when the audio service starts first.
class FinampAndroidStartup {
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/android_startup');

  /// Whether Android's keyguard is currently displayed.
  static Future<bool?> isKeyguardLocked() => _channel.invokeMethod<bool>('getIsKeyguardLocked');
}
