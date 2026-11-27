import 'package:flutter/services.dart';

/// Android facts used to decide whether restoring a saved queue may autoplay.
class FinampAndroidStartupState {
  const FinampAndroidStartupState({
    required this.isKeyguardLocked,
    required this.uptime,
    required this.packageUpdateAge,
    required this.userPresentSinceBoot,
    required this.userPresentSinceUpdate,
  });

  factory FinampAndroidStartupState.fromMap(Map<Object?, Object?> map) {
    final isKeyguardLocked = map['isKeyguardLocked'];
    final uptimeMillis = map['uptimeMillis'];
    final packageUpdateAgeMillis = map['packageUpdateAgeMillis'];
    final userPresentSinceBoot = map['userPresentSinceBoot'];
    final userPresentSinceUpdate = map['userPresentSinceUpdate'];
    if (isKeyguardLocked is! bool ||
        uptimeMillis is! num ||
        packageUpdateAgeMillis is! num ||
        userPresentSinceBoot is! bool ||
        userPresentSinceUpdate is! bool) {
      throw const FormatException('Invalid Android startup state');
    }
    return FinampAndroidStartupState(
      isKeyguardLocked: isKeyguardLocked,
      uptime: Duration(milliseconds: uptimeMillis.toInt()),
      packageUpdateAge: Duration(milliseconds: packageUpdateAgeMillis.toInt()),
      userPresentSinceBoot: userPresentSinceBoot,
      userPresentSinceUpdate: userPresentSinceUpdate,
    );
  }

  final bool isKeyguardLocked;
  final Duration uptime;
  final Duration packageUpdateAge;
  final bool userPresentSinceBoot;
  final bool userPresentSinceUpdate;
}

/// Android startup state, available even when the audio service starts first.
class FinampAndroidStartup {
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/android_startup');

  /// Reads the Android state captured when Finamp starts restoring its queue.
  static Future<FinampAndroidStartupState?> getStartupState() async {
    final state = await _channel.invokeMapMethod<Object?, Object?>('getStartupState');
    return state == null ? null : FinampAndroidStartupState.fromMap(state);
  }
}
