import 'package:finamp/components/HomeScreen/quick_action_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ({double width, bool vertical}) layout(double usableWidth, int count, int index, {double maxWidth = 600}) =>
      quickActionButtonLayout(usableWidth: usableWidth, maxWidth: maxWidth, actionCount: count, index: index);

  group('quickActionsHorizontalPadding', () {
    test('keeps the minimum padding on narrow screens', () {
      expect(quickActionsHorizontalPadding(usableWidth: 411, maxWidth: 600), 14);
      expect(quickActionsHorizontalPadding(usableWidth: 0, maxWidth: 600), 14);
    });

    test('centres the buttons on wide screens', () {
      expect(quickActionsHorizontalPadding(usableWidth: 1200, maxWidth: 800), 214);
    });
  });

  group('quickActionButtonLayout on a phone (411 wide)', () {
    // Usable width for the buttons: 411 - 2 * 14 = 383
    test('one action fills the row', () {
      expect(layout(411, 1, 0), (width: 383, vertical: false));
    });

    test('three actions share a row as tall buttons', () {
      expect(layout(411, 3, 0).width, closeTo(383 / 3 - 10, 1e-9));
      expect(layout(411, 3, 0).vertical, isTrue);
    });

    test('four actions make two rows of two', () {
      for (var i = 0; i < 4; i++) {
        expect(layout(411, 4, i), (width: 383 / 2 - 8, vertical: false));
      }
    });

    test('five actions put three tall buttons first, then two wide ones', () {
      expect([for (var i = 0; i < 5; i++) layout(411, 5, i).vertical], [true, true, true, false, false]);
    });

    test('seven actions put three tall buttons first, then two rows of two', () {
      expect([for (var i = 0; i < 7; i++) layout(411, 7, i).vertical], [true, true, true, false, false, false, false]);
    });
  });

  test('desktop widths are capped at the maximum', () {
    // 1200 wide, max 800: padding 214, usable 1200 - 428 = 772
    expect(layout(1200, 4, 0, maxWidth: 800), (width: 772 / 2 - 8, vertical: false));
  });

  group('quickActionButtonLayout before the window has a size', () {
    for (final usableWidth in [0.0, 10.0, 40.0]) {
      test('never returns a negative width at $usableWidth wide', () {
        for (var count = 1; count <= 7; count++) {
          for (var index = 0; index < count; index++) {
            expect(layout(usableWidth, count, index).width, greaterThanOrEqualTo(0), reason: '$count actions, #$index');
          }
        }
      });
    }

    test('keeps the same button style as at normal widths', () {
      expect([for (var i = 0; i < 5; i++) layout(0, 5, i).vertical], [true, true, true, false, false]);
      expect(layout(0, 4, 0).vertical, isFalse);
    });
  });
}
