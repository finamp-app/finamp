import 'package:finamp/services/tray_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrayService.resolveLocalizations', () {
    test('resolves configured locale with zero frames drawn', () {
      final l10n = TrayService.resolveLocalizations(
        preferredLocale: const Locale('it'),
        systemLocales: const [Locale('en')],
      );
      expect(l10n.localeName, startsWith('it'));
      expect(l10n.trayQuit, isNotEmpty);
    });

    test('falls back to English when locale is unsupported', () {
      final l10n = TrayService.resolveLocalizations(
        preferredLocale: const Locale('zz'),
        systemLocales: const [Locale('yy')],
      );
      expect(l10n.localeName, 'en');
    });
  });
}
