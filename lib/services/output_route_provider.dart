import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool> _currentRouteIsAirPlay(AVAudioSession session) async {
  final route = await session.currentRoute;
  return route.outputs.any((port) => port.portType == AVAudioSessionPort.airPlay);
}

/// Emits whether AirPlay is currently the active audio output route.
///
/// This is only meaningful on iOS, where the per-app volume slider has no
/// audible effect while audio is rendered by an AirPlay receiver. On all other
/// platforms (and for non-AirPlay routes such as Bluetooth or the device
/// speaker) this stays `false`.
///
/// We listen to [AVAudioSession.routeChangeStream] directly rather than
/// `audio_session`'s `devicesStream`, because the latter only emits for route
/// changes with an added/removed device. Selecting an already-available AirPlay
/// target instead produces an `override`/`routeConfigurationChange` reason,
/// which `devicesStream` filters out, so it would miss most AirPlay toggles.
final airPlayActiveProvider = StreamProvider<bool>((ref) async* {
  if (!Platform.isIOS) {
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
