import 'package:finamp/services/tray_service.dart';
import 'package:flutter/services.dart';
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

  group('TrayService native window channel', () {
    const channel = MethodChannel('finamp/window');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('setNativeStartHidden sends setStartHidden over finamp/window channel', () async {
      await TrayService.setNativeStartHidden(true);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setStartHidden');
      expect(calls.single.arguments, isTrue);

      await TrayService.setNativeStartHidden(false);
      expect(calls, hasLength(2));
      expect(calls.last.method, 'setStartHidden');
      expect(calls.last.arguments, isFalse);
    });
  });
}
