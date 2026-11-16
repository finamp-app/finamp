import 'dart:ui';

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/window_size_saver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowSizeSaver', () {
    late List<ScreenSize> saved;
    late int boundsReads;
    late Rect bounds;

    WindowSizeSaver createSaver() {
      return WindowSizeSaver(
        getBounds: () async {
          boundsReads++;
          return bounds;
        },
        saveScreenSize: saved.add,
      );
    }

    setUp(() {
      saved = [];
      boundsReads = 0;
      bounds = const Rect.fromLTWH(100, 200, 1280, 720);
    });

    testWidgets('saves bounds when the window finished moving or resizing', (tester) async {
      final saver = createSaver();
      addTearDown(saver.dispose);

      saver.onWindowEvent('moved');
      await tester.pump();

      expect(saved, hasLength(1));
      expect(saved.single.size, const Size(1280, 720));
      expect(saved.single.location, const Offset(100, 200));

      bounds = const Rect.fromLTWH(50, 75, 1024, 768);
      saver.onWindowEvent('resized');
      await tester.pump();

      expect(saved, hasLength(2));
      expect(saved.last.size, const Size(1024, 768));
      expect(saved.last.location, const Offset(50, 75));
    });

    testWidgets('debounces move and resize events into a single save', (tester) async {
      final saver = createSaver();
      addTearDown(saver.dispose);

      saver.onWindowEvent('move');
      saver.onWindowEvent('resize');
      saver.onWindowEvent('move');

      await tester.pump(const Duration(milliseconds: 499));
      expect(saved, isEmpty);

      bounds = const Rect.fromLTWH(20, 30, 640, 480);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(boundsReads, 1);
      expect(saved, hasLength(1));
      expect(saved.single.size, const Size(640, 480));
      expect(saved.single.location, const Offset(20, 30));
    });

    testWidgets('does not read bounds on close when the window is being destroyed', (tester) async {
      final saver = createSaver();
      addTearDown(saver.dispose);

      saver.onWindowEvent('move');
      await saver.onWindowClose(isPreventClose: false);

      await tester.pump(const Duration(seconds: 1));

      expect(boundsReads, 0);
      expect(saved, isEmpty);
    });

    testWidgets('saves bounds on close when the close is intercepted', (tester) async {
      final saver = createSaver();
      addTearDown(saver.dispose);

      await saver.onWindowClose(isPreventClose: true);
      await tester.pump();

      expect(boundsReads, 1);
      expect(saved.single.size, const Size(1280, 720));
      expect(saved.single.location, const Offset(100, 200));
    });

    testWidgets('cancels a pending debounced save when disposed', (tester) async {
      final saver = createSaver();

      saver.onWindowEvent('resize');
      saver.dispose();
      await tester.pump(const Duration(seconds: 1));

      expect(saved, isEmpty);
    });
  });

  group('ScreenSize', () {
    test('creates valid size and location from Rect bounds', () {
      const bounds = Rect.fromLTWH(100, 200, 1280, 720);
      final screenSize = ScreenSize.from(bounds);

      expect(screenSize.sizeX, 1280);
      expect(screenSize.sizeY, 720);
      expect(screenSize.size, const Size(1280, 720));
      expect(screenSize.location.dx, 100);
      expect(screenSize.location.dy, 200);
    });

    test('preserves custom dimensions and positions', () {
      final screenSize = ScreenSize(1024, 768, 50, 75);

      expect(screenSize.size, const Size(1024, 768));
      expect(screenSize.location, const Offset(50, 75));
    });
  });
}
