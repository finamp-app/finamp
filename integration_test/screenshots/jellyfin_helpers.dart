import 'package:finamp/components/Buttons/cta_huge.dart';
import 'package:finamp/components/LoginScreen/login_server_selection_page.dart';
import 'package:finamp/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

Future<void> loginToJellyfin(WidgetTester tester) async {
  await tester.waitFor(find.byType(LoginScreen));

  final startButton = find.byType(CTAHuge);
  await tester.tap(startButton);
  await tester.pump();

  final serverUrl = const String.fromEnvironment("JELLYFIN_SERVER", defaultValue: "https://demo.jellyfin.org/stable");
  final username = const String.fromEnvironment("JELLYFIN_USER", defaultValue: "demo");
  final password = const String.fromEnvironment("JELLYFIN_PASSWORD", defaultValue: "");

  final urlEntry = find.byType(TextFormField);
  await tester.enterText(urlEntry, serverUrl);

  final serverButton = find.byWidgetPredicate(
    (x) => x is JellyfinServerSelectionWidget && (x.baseUrl?.contains(serverUrl) ?? false),
  );
  await tester.waitFor(serverButton);
  await tester.tap(serverButton);
  await tester.pump(Duration(seconds: 1));

  final customUserButton = find.text("Custom User");
  await tester.tap(customUserButton);
  await tester.pump(Duration(seconds: 1));

  final userTextField = find.byType(TextFormField).first;
  await tester.enterText(userTextField, username);
  final passwordTextField = find.byType(TextFormField).at(1);
  await tester.enterText(passwordTextField, password);
  final loginButton = find.text("Log In");
  await tester.tap(loginButton);
  await tester.pumpAndSettle();

  final floatingActionButtonFinder = find.byType(FloatingActionButton);
  if (tester.any(floatingActionButtonFinder)) {
    await tester.tap(floatingActionButtonFinder);
    await tester.pumpAndSettle();
  }
}
