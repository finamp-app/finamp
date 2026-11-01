import 'package:finamp/services/android_startup_autoplay_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidStartupAutoplayGuard.mayAutoplayWhileKeyguardLocked', () {
    test('suppresses autoplay while the keyguard is locked', () {
      expect(AndroidStartupAutoplayGuard.mayAutoplayWhileKeyguardLocked(true), isFalse);
    });

    test('allows autoplay after the keyguard is unlocked', () {
      expect(AndroidStartupAutoplayGuard.mayAutoplayWhileKeyguardLocked(false), isTrue);
    });
  });
}
