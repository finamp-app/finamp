import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tief_screen/tief_screen.dart';

part "screenshot_manager_provider.g.dart";

@Riverpod(keepAlive: true)
class ScreenshotManagerState extends _$ScreenshotManagerState {
  @override
  ScreenshotManager? build() => null;

  void initialize(String host, int port) =>
      state = ScreenshotManager(host: host, port: port);
}
