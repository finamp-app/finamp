import 'package:finamp/services/network_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldNotifyPausedDownloads', () {
    test('warns when Wi-Fi-only downloads pause after a local-to-cellular hand-off', () {
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.localNetwork,
          currentState: FinampConnectivityState.cellular,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isTrue,
      );
    });

    test('does not warn for Offline Mode or a non-cellular hand-off', () {
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.none,
          currentState: FinampConnectivityState.localNetwork,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isFalse,
      );
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.localNetwork,
          currentState: FinampConnectivityState.none,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isFalse,
      );
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.cellular,
          currentState: FinampConnectivityState.localNetwork,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isFalse,
      );
    });

    test('does not warn without active downloads, Wi-Fi-only downloads, or a mobile platform', () {
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.localNetwork,
          currentState: FinampConnectivityState.cellular,
          activeDownloads: 0,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isFalse,
      );
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.localNetwork,
          currentState: FinampConnectivityState.cellular,
          activeDownloads: 1,
          requireWifiForDownloads: false,
          isMobilePlatform: true,
        ),
        isFalse,
      );
      expect(
        shouldNotifyPausedDownloads(
          previousState: FinampConnectivityState.localNetwork,
          currentState: FinampConnectivityState.cellular,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: false,
        ),
        isFalse,
      );
    });
  });
}
