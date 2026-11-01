import 'package:finamp/services/android_startup_autoplay_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidStartupAutoplayGuard.hasCompletedStartupGracePeriod', () {
    test('suppresses autoplay before three minutes', () {
      expect(
        AndroidStartupAutoplayGuard.hasCompletedStartupGracePeriod(const Duration(minutes: 2, seconds: 59)),
        isFalse,
      );
    });

    test('allows autoplay at and after three minutes', () {
      expect(AndroidStartupAutoplayGuard.hasCompletedStartupGracePeriod(const Duration(minutes: 3)), isTrue);
      expect(
        AndroidStartupAutoplayGuard.hasCompletedStartupGracePeriod(const Duration(minutes: 3, seconds: 1)),
        isTrue,
      );
    });
  });
}
