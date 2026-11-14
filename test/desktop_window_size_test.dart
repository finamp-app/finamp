import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Window Size Persistence', () {
    test('ScreenSize.from creates valid size and location from Rect bounds', () {
      const bounds = Rect.fromLTWH(100, 200, 1280, 720);
      final screenSize = ScreenSize.from(bounds);

      expect(screenSize.sizeX, 1280);
      expect(screenSize.sizeY, 720);
      expect(screenSize.size, const Size(1280, 720));
      expect(screenSize.location.dx, 100);
      expect(screenSize.location.dy, 200);
    });

    test('ScreenSize preserves custom dimensions and positions', () {
      final screenSize = ScreenSize(1024, 768, 50, 75);

      expect(screenSize.size, const Size(1024, 768));
      expect(screenSize.location, const Offset(50, 75));
    });
  });
}
