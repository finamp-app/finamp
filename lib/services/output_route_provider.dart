import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isAirPlayActive(Set<AudioDevice> devices) =>
    devices.any((device) => device.isOutput && device.type == AudioDeviceType.airPlay);

/// Emits whether AirPlay is currently the active audio output route.
///
/// This is only meaningful on iOS, where the per-app volume slider has no
/// audible effect while audio is rendered by an AirPlay receiver. On all other
/// platforms (and for non-AirPlay routes such as Bluetooth or the device
/// speaker) this stays `false`.
final airPlayActiveProvider = StreamProvider<bool>((ref) async* {
  if (!Platform.isIOS) {
    yield false;
    return;
  }
  final session = await AudioSession.instance;
  // Emit the current route immediately, then follow subsequent route changes.
  yield _isAirPlayActive(await session.getDevices(includeInputs: false));
  yield* session.devicesStream.map(_isAirPlayActive);
});
