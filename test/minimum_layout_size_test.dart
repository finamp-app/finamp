import 'package:finamp/components/minimum_layout_size.dart';
import 'package:finamp/components/PlayerScreen/player_split_screen_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinimumLayoutSize', () {
    testWidgets('clamps layout constraints and MediaQuery size when parent is smaller than minSize', (tester) async {
      late BoxConstraints capturedConstraints;
      late Size capturedMediaSize;
      final childKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 150,
              height: 100,
              child: MinimumLayoutSize(
                minSize: const Size(400, 250),
                child: LayoutBuilder(
                  key: childKey,
                  builder: (context, constraints) {
                    capturedConstraints = constraints;
                    capturedMediaSize = MediaQuery.sizeOf(context);
                    return Row(
                      children: [
                        Container(width: 250, height: 200, color: Colors.red),
                        Container(width: 150, height: 200, color: Colors.blue),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(capturedConstraints.maxWidth, 400);
      expect(capturedConstraints.maxHeight, 250);
      expect(capturedMediaSize.width, greaterThanOrEqualTo(400));
      expect(capturedMediaSize.height, greaterThanOrEqualTo(250));
    });

    testWidgets('passes through larger constraints without reparenting child across threshold', (tester) async {
      final statefulKey = GlobalKey<_CountMountState>();

      Widget buildWithSize(Size size) {
        return MaterialApp(
          home: Center(
            child: SizedBox.fromSize(
              size: size,
              child: MinimumLayoutSize(
                minSize: const Size(400, 250),
                child: _CountMount(key: statefulKey),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWithSize(const Size(600, 400)));
      expect(statefulKey.currentState!.initCount, 1);

      await tester.pumpWidget(buildWithSize(const Size(120, 80)));
      expect(statefulKey.currentState!.initCount, 1);

      await tester.pumpWidget(buildWithSize(const Size(900, 700)));
      expect(statefulKey.currentState!.initCount, 1);
    });
  });

  group('DelayedFlag', () {
    testWidgets('ignores transient size spikes shorter than delay and switches after sustained change', (tester) async {
      final observedValues = <bool>[];

      Widget buildFlag(bool value) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: DelayedFlag(
            value: value,
            delay: const Duration(milliseconds: 150),
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

      // Transient spike to true (e.g. Wayland remap 1280x720) for 50ms, then back to false
      await tester.pumpWidget(buildFlag(true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(observedValues.last, isFalse);

      await tester.pumpWidget(buildFlag(false));
      await tester.pump(const Duration(milliseconds: 200));
      expect(observedValues.last, isFalse);

      // Sustained change to true
      await tester.pumpWidget(buildFlag(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(observedValues.last, isFalse);
      await tester.pump(const Duration(milliseconds: 60));
      expect(observedValues.last, isTrue);
    });
  });
}

class _CountMount extends StatefulWidget {
  const _CountMount({super.key});

  @override
  State<_CountMount> createState() => _CountMountState();
}

class _CountMountState extends State<_CountMount> {
  static int _totalInits = 0;
  int get initCount => _totalInits;

  @override
  void initState() {
    super.initState();
    _totalInits++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
