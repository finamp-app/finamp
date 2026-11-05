import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connectivityStateFromResults', () {
    test('keeps an explicitly disconnected transport offline', () {
      expect(connectivityStateFromResults([ConnectivityResult.none]), FinampConnectivityState.none);
      expect(connectivityStateFromResults([]), FinampConnectivityState.none);
    });

    test('uses the underlying transport when Android also reports a VPN', () {
      expect(
        connectivityStateFromResults([ConnectivityResult.wifi, ConnectivityResult.vpn]),
        FinampConnectivityState.localNetwork,
      );
      expect(
        connectivityStateFromResults([ConnectivityResult.vpn, ConnectivityResult.mobile]),
        FinampConnectivityState.cellular,
      );
    });

    test('keeps a VPN-only transport undecided until server probes complete', () {
      expect(connectivityStateFromResults([ConnectivityResult.vpn]), FinampConnectivityState.vpn);
    });
  });

  group('offlineModeForConnectivity', () {
    test('keeps a usable VPN-only route online in disconnected mode', () {
      expect(
        offlineModeForConnectivity(
          autoOffline: AutoOfflineOption.disconnected,
          state: FinampConnectivityState.vpn,
          activeServerReachable: true,
        ),
        isFalse,
      );
    });

    test('enters offline mode only after a VPN-only route cannot reach the server', () {
      expect(
        offlineModeForConnectivity(
          autoOffline: AutoOfflineOption.disconnected,
          state: FinampConnectivityState.vpn,
          activeServerReachable: false,
        ),
        isTrue,
      );
      expect(
        offlineModeForConnectivity(autoOffline: AutoOfflineOption.disconnected, state: FinampConnectivityState.vpn),
        isNull,
      );
    });

    test('uses local reachability for a VPN-only route in network mode', () {
      expect(
        offlineModeForConnectivity(
          autoOffline: AutoOfflineOption.network,
          state: FinampConnectivityState.vpn,
          localServerReachable: true,
        ),
        isFalse,
      );
      expect(
        offlineModeForConnectivity(
          autoOffline: AutoOfflineOption.network,
          state: FinampConnectivityState.vpn,
          localServerReachable: false,
        ),
        isTrue,
      );
    });
  });

  group('shouldDelayOfflineModeExit', () {
    test('keeps the app offline until the restored route has been selected', () {
      expect(
        shouldDelayOfflineModeExit(
          isOffline: true,
          state: FinampConnectivityState.localNetwork,
          selectedLocalUrl: null,
        ),
        isTrue,
      );
    });

    test('does not delay once a local or public route is known', () {
      for (final selectedLocalUrl in [true, false]) {
        expect(
          shouldDelayOfflineModeExit(
            isOffline: true,
            state: FinampConnectivityState.localNetwork,
            selectedLocalUrl: selectedLocalUrl,
          ),
          isFalse,
        );
      }
    });

    test('does not wait while disconnected or when already online', () {
      expect(
        shouldDelayOfflineModeExit(isOffline: true, state: FinampConnectivityState.none, selectedLocalUrl: null),
        isFalse,
      );
      expect(
        shouldDelayOfflineModeExit(
          isOffline: false,
          state: FinampConnectivityState.localNetwork,
          selectedLocalUrl: null,
        ),
        isFalse,
      );
    });
  });
}
