import 'package:finamp/components/PlayerScreen/player_split_screen_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DelayedFlag', () {
    testWidgets('ignores transient single-frame size spikes and switches after sustained frame', (tester) async {
      final observedValues = <bool>[];

      Widget buildFlag(bool value) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: DelayedFlag(
            value: value,
            waitForNextFrame: true,
            builder: (context, effectiveValue) {
              observedValues.add(effectiveValue);
              return const SizedBox.shrink();
            },
          ),
        );
      }

      // Start small (false)
      await tester.pumpWidget(buildFlag(false));
      expect(observedValues.last, isFalse);

      // Transient spike to true (e.g. Wayland remap default size), then back to false
      await tester.pumpWidget(buildFlag(true));
      expect(observedValues.last, isFalse); // still false on current frame

      await tester.pumpWidget(buildFlag(false));
      await tester.pump();
      expect(observedValues.last, isFalse); // discarded transient spike, stays false

      // Sustained change to true
      await tester.pumpWidget(buildFlag(true));
      expect(observedValues.last, isFalse); // frame 1: still false
      await tester.pump(); // frame 2: post-frame callback triggers rebuild
      expect(observedValues.last, isTrue); // switches on next frame
    });

    testWidgets('updates immediately when waitForNextFrame is false', (tester) async {
      final observedValues = <bool>[];

      Widget buildFlag(bool value) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: DelayedFlag(
            value: value,
            waitForNextFrame: false,
            builder: (context, effectiveValue) {
              observedValues.add(effectiveValue);
              return const SizedBox.shrink();
            },
          ),
        );
      }

      await tester.pumpWidget(buildFlag(false));
      expect(observedValues.last, isFalse);

      await tester.pumpWidget(buildFlag(true));
      expect(observedValues.last, isTrue);
    });
  });
}
