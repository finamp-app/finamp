import 'package:finamp/components/LoginScreen/server_discovery_status.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget screen({bool hasServers = false, Key? statusKey}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ServerDiscoveryStatus(key: statusKey, hasServers: hasServers),
  ),
);

void main() {
  const hint = 'No servers detected yet - you may need to manually enter the server address.';
  const scanning = 'Scanning for servers…';

  testWidgets('manual connection guidance keeps the ongoing search visible', (tester) async {
    await tester.pumpWidget(screen());
    final indicator = tester.element(find.byType(CircularProgressIndicator));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(scanning), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text(hint), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.element(find.byType(CircularProgressIndicator)), same(indicator));
    expect(find.text(scanning), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
    expect(tester.getTopLeft(find.text(hint)).dy, greaterThan(tester.getBottomLeft(find.text(scanning)).dy));
  });

  testWidgets('a late server hides the hint without interrupting the search indicator', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(seconds: 8));
    expect(find.text(hint), findsOneWidget);
    final indicator = tester.element(find.byType(CircularProgressIndicator));
    await tester.pumpWidget(screen(hasServers: true));
    expect(find.text(hint), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.element(find.byType(CircularProgressIndicator)), same(indicator));
    expect(find.text(scanning), findsOneWidget);
  });

  testWidgets('a server found during the initial wait never shows the empty hint', (tester) async {
    await tester.pumpWidget(screen(hasServers: true));
    await tester.pump(const Duration(seconds: 8));
    expect(find.text(hint), findsNothing);
    expect(find.text(scanning), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('leaving the screen cancels the pending update', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh discovery session gets a fresh initial wait', (tester) async {
    await tester.pumpWidget(screen(statusKey: const ValueKey(1)));
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(screen(statusKey: const ValueKey(2)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(hint), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('search and guidance fit a narrow screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(seconds: 8));
    expect(find.text(hint), findsOneWidget);
    expect(find.text(scanning), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
