import 'dart:io';

import 'package:finamp/services/android_startup_autoplay_guard.dart';
import 'package:finamp_android_startup/finamp_android_startup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidStartupAutoplayGuard.autoplaySuppressionReason', () {
    FinampAndroidStartupState state({
      bool keyguardLocked = false,
      int uptimeSeconds = 121,
      int packageUpdateAgeSeconds = 121,
      bool userPresentSinceBoot = false,
      bool userPresentSinceUpdate = false,
    }) => FinampAndroidStartupState(
      isKeyguardLocked: keyguardLocked,
      uptime: Duration(seconds: uptimeSeconds),
      packageUpdateAge: Duration(seconds: packageUpdateAgeSeconds),
      userPresentSinceBoot: userPresentSinceBoot,
      userPresentSinceUpdate: userPresentSinceUpdate,
    );

    test('suppresses autoplay while the keyguard is locked', () {
      expect(AndroidStartupAutoplayGuard.autoplaySuppressionReason(state(keyguardLocked: true)), isNotNull);
    });

    test('a user-present event never overrides a currently locked keyguard', () {
      expect(
        AndroidStartupAutoplayGuard.autoplaySuppressionReason(
          state(keyguardLocked: true, userPresentSinceBoot: true, userPresentSinceUpdate: true),
        ),
        isNotNull,
      );
    });

    test('suppresses autoplay during the boot grace period without user activity', () {
      expect(AndroidStartupAutoplayGuard.autoplaySuppressionReason(state(uptimeSeconds: 119)), isNotNull);
    });

    test('user presence allows autoplay before the boot grace period expires', () {
      expect(
        AndroidStartupAutoplayGuard.autoplaySuppressionReason(state(uptimeSeconds: 119, userPresentSinceBoot: true)),
        isNull,
      );
    });

    test('suppresses autoplay immediately after an update without user activity', () {
      expect(AndroidStartupAutoplayGuard.autoplaySuppressionReason(state(packageUpdateAgeSeconds: 119)), isNotNull);
    });

    test('user presence allows autoplay immediately after an update', () {
      expect(
        AndroidStartupAutoplayGuard.autoplaySuppressionReason(
          state(packageUpdateAgeSeconds: 119, userPresentSinceUpdate: true),
        ),
        isNull,
      );
    });

    test('allows autoplay after both grace periods expire', () {
      expect(AndroidStartupAutoplayGuard.autoplaySuppressionReason(state()), isNull);
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

    test('parses a complete startup state from the Android plugin', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getStartupState');
        return {
          'isKeyguardLocked': false,
          'uptimeMillis': 123000,
          'packageUpdateAgeMillis': 456000,
          'userPresentSinceBoot': true,
          'userPresentSinceUpdate': false,
        };
      });
      final state = await FinampAndroidStartup.getStartupState();
      expect(state!.isKeyguardLocked, isFalse);
      expect(state.uptime, const Duration(seconds: 123));
      expect(state.packageUpdateAge, const Duration(seconds: 456));
      expect(state.userPresentSinceBoot, isTrue);
      expect(state.userPresentSinceUpdate, isFalse);
    });

    test('propagates plugin errors for the guard to handle', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => throw PlatformException(code: 'unavailable'));
      await expectLater(FinampAndroidStartup.getStartupState(), throwsA(isA<PlatformException>()));
    });

    test('passes through a null response', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await FinampAndroidStartup.getStartupState(), isNull);
    });

    test('reports a missing plugin', () async {
      await expectLater(FinampAndroidStartup.getStartupState(), throwsA(isA<MissingPluginException>()));
    });
  });
}
