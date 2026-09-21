import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:finamp/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

Future<(bool, List<FlutterErrorDetails>)> initializeApp() async {
  bool mainCompleted = false;
  List<FlutterErrorDetails> mainErrors = [];

  // If main throws an error, the future runZoneGuarded returns will never complete, so do not await it.
  // Instead, we will simply check that main has completed with no errors after a 30 second timeout. This also
  // allows some errors thrown by the background services to be caught before the following tests start.
  unawaited(
    runZonedGuarded(
      () async {
        // Login testing flag redirects file accesses to testing folder and clears it on startup.
        // Download base directories are not redirected, so loginTesting flag should be avoided on mobile.
        // Note that this means mobile integration test runs will require manual file clearing outside of CI
        await app.main([], integrationTesting: true, loginTesting: !(Platform.isAndroid || Platform.isIOS));
        mainCompleted = true;
      },
      (e, stack) {
        // Linux throws DBusServiceUnknownException due to dbus service org.freedesktop.UPower
        // missing in CI. Ignore.
        if (e is DBusServiceUnknownException) return;

        mainErrors.add(FlutterErrorDetails(exception: e, stack: stack));
      },
    ),
  );

  Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < Duration(seconds: 30)) {
    if (mainCompleted) return (true, mainErrors);

    await Future<void>.delayed(Duration(seconds: 1));
  }

  return (mainCompleted, mainErrors);
}

extension WaitForElement on WidgetTester {
  Future<void> waitFor(Finder finder, {int seconds = 20, bool realtime = true}) async {
    int i = 0;
    while (true) {
      await pump(Duration(seconds: 1));
      if (any(finder)) {
        return;
      }
      if (i >= seconds) {
        throw "$finder never found expected widget after $seconds seconds.";
      }
      i++;
      if (realtime) {
        await Future<void>.delayed(Duration(seconds: 1));
      }
    }
  }
}
