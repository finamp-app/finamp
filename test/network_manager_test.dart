import 'package:finamp/services/network_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldNotifyPausedDownloads', () {
    test('does not warn during a cellular-to-Wi-Fi hand-off before Offline Mode is entered', () {
      expect(
        shouldNotifyPausedDownloads(
          state: FinampConnectivityState.cellular,
          isOffline: false,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isFalse,
      );
    });

    test('warns for cellular downloads only after Offline Mode is active', () {
      expect(
        shouldNotifyPausedDownloads(
          state: FinampConnectivityState.cellular,
          isOffline: true,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isTrue,
      );
    });

    test('warns when offline with active downloads, but not after a local transport returns', () {
      expect(
        shouldNotifyPausedDownloads(
          state: FinampConnectivityState.none,
          isOffline: true,
          activeDownloads: 1,
          requireWifiForDownloads: false,
          isMobilePlatform: false,
        ),
        isTrue,
      );
      expect(
        shouldNotifyPausedDownloads(
          state: FinampConnectivityState.localNetwork,
          isOffline: true,
          activeDownloads: 1,
          requireWifiForDownloads: true,
          isMobilePlatform: true,
        ),
        isFalse,
      );
    });
  });
}
