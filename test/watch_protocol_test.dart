import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the watch (Swift), the phone (Dart) and lib/services/watch_protocol.md in step: the same requests and pushes
/// on every side. It reads the sources as text, so it runs anywhere Flutter tests run, with no watch or Xcode.
const _helper = 'lib/services/watch_helper.dart';
const _protocol = 'lib/services/watch_protocol.md';
const _watch = 'ios/FinampWatch Watch App/PhoneConnection.swift';
const _bridge = 'ios/Runner/WatchBridge.swift';

Set<String> _names(String text, String pattern) =>
    RegExp(pattern, multiLine: true).allMatches(text).map((match) => match.group(1)!).toSet();

/// The text between [start] and the next occurrence of [end].
String _between(String text, String start, String end) {
  final from = text.indexOf(start);
  if (from == -1) throw StateError('missing "$start"');
  final to = text.indexOf(end, from + start.length);
  return text.substring(from, to == -1 ? text.length : to);
}

void main() {
  final helper = File(_helper).readAsStringSync();
  final protocol = File(_protocol).readAsStringSync();
  final watch = File(_watch).readAsStringSync();
  final bridge = File(_bridge).readAsStringSync();

  // WatchHandler's request switch: its own cases only, not the nested ones (indented further)
  final requestSwitch = _between(helper, 'switch (call.method) {', '\n          default:');
  final handled = _names(requestSwitch, r"^          case '(\w+)':")..remove('watchState'); // iOS's own query
  final answeredNatively = _names(bridge, r'method == "(\w+)"');
  final sent = _names(watch, r'request\("(\w+)"');
  final documentedRequests = _names(_between(protocol, '## Requests', '## Pushes'), r'^\| `(\w+)` \|');

  final pushed = _names(helper, r"_pushIfChanged\('(\w+)'")..addAll(_names(helper, r"invokeMethod\('(nowPlaying)'"));
  final applied = _names(watch, r'values\["(\w+)"\]');
  final relayed = _names(bridge, r'"(\w+)" where call\.arguments is'); // what iOS forwards to the watch
  final documentedPushes = _names(_between(protocol, '## Pushes', '## Flutter'), r'^\| `(\w+)` \|');

  test('every request the watch sends is answered on the phone', () {
    expect(sent.difference(handled.union(answeredNatively)), isEmpty);
  });

  test('the phone answers no request the watch never sends', () {
    expect(handled.difference(sent), isEmpty);
  });

  test('watch_protocol.md lists exactly the requests the watch sends', () {
    expect(documentedRequests, equals(sent));
  });

  test('the phone pushes exactly what iOS forwards and the watch applies, as documented', () {
    expect(relayed, equals(pushed));
    expect(applied, equals(pushed));
    expect(documentedPushes, equals(pushed));
  });
}
