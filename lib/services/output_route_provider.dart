import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> _currentRouteIsAirPlay(AVAudioSession session) async {
  final route = await session.currentRoute;
  return route.outputs.any((port) => port.portType == AVAudioSessionPort.airPlay);
}

/// Emits whether the app's own audio is currently being rendered by an AirPlay
/// receiver, such that the in-app per-app volume slider has no audible effect.
///
/// Only meaningful on iOS. On all other platforms (and for non-AirPlay routes
/// such as Bluetooth or the device speaker) this stays `false`.
///
/// Note on the "iOS app on Mac" build: the app can independently cast its audio
/// to AirPlay, but that route is invisible to every public API on the
/// Designed-for-iPad runtime — `AVAudioSession.currentRoute` reports the
/// built-in speaker and `MPVolumeView.isWirelessRouteActive` is `false`, because
/// macOS routes the app's output to AirPlay at a layer the app can't observe. So
/// we can't detect it there and intentionally leave the slider enabled. That is
/// also the correct behavior when the app plays through the system output device
/// (even one that is itself on AirPlay), where the per-app volume still applies.
final airPlayActiveProvider = StreamProvider<bool>((ref) async* {
  if (!Platform.isIOS) {
    yield false;
    return;
  }
  // The detection below relies on the app's audio session route reflecting the
  // app's output, which is not the case on the iOS-app-on-Mac build (see above).
  if ((await DeviceInfoPlugin().iosInfo).isiOSAppOnMac) {
    yield false;
    return;
  }
  final session = AVAudioSession();
  // Emit the current route immediately, then re-check on every route change.
  yield await _currentRouteIsAirPlay(session);
  await for (final _ in session.routeChangeStream) {
    yield await _currentRouteIsAirPlay(session);
  }
});
