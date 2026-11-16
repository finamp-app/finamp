import 'dart:io';

import 'package:finamp/services/android_startup_autoplay_guard.dart';
import 'package:finamp_android_startup/finamp_android_startup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidStartupAutoplayGuard.mayAutoplayWhileKeyguardLocked', () {
    test('suppresses autoplay while the keyguard is locked', () {
      expect(AndroidStartupAutoplayGuard.mayAutoplayWhileKeyguardLocked(true), isFalse);
    });

    test('allows autoplay after the keyguard is unlocked', () {
      expect(AndroidStartupAutoplayGuard.mayAutoplayWhileKeyguardLocked(false), isTrue);
    });
  });

  test('non-Android startup preserves autoplay behavior', () async {
    if (!Platform.isAndroid) {
      expect(await AndroidStartupAutoplayGuard.mayAutoplayInitialQueue(), isTrue);
    }
  });

  group('FinampAndroidStartup', () {
    const channel = MethodChannel('com.unicornsonlsd.finamp/android_startup');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    for (final locked in [true, false]) {
      test('returns $locked from the Android plugin', () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getIsKeyguardLocked');
          return locked;
        });
        expect(await FinampAndroidStartup.isKeyguardLocked(), locked);
      });
    }

    test('propagates plugin errors for the guard to handle', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => throw PlatformException(code: 'unavailable'));
      await expectLater(FinampAndroidStartup.isKeyguardLocked(), throwsA(isA<PlatformException>()));
    });

    test('passes through a null response', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await FinampAndroidStartup.isKeyguardLocked(), isNull);
    });

    test('reports a missing plugin', () async {
      await expectLater(FinampAndroidStartup.isKeyguardLocked(), throwsA(isA<MissingPluginException>()));
    });
  });
}
