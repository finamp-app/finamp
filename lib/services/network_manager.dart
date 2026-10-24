import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/playon_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/finamp_models.dart';
import 'finamp_settings_helper.dart';

part 'network_manager.g.dart';

final _networkAutomationLogger = Logger('Network Automation');

enum FinampConnectivityState { localNetwork, cellular, none }

enum ServerPingType { local, remote, active }

late List<ConnectivityResult> _latestConnectivity;
Timer? _localReachabilityRetry;
Timer? _playOnReconnectRetry;

const _localReachabilityRetryDelay = Duration(seconds: 3);

Future<void> startNetworkAutomation() async {
  final container = GetIt.instance<ProviderContainer>();
  _latestConnectivity = await Connectivity().checkConnectivity();
  Connectivity().onConnectivityChanged.listen(_onConnectivityChange);

  container.listen(setLocalUrlProvider, (_, isLocal) {
    if (isLocal == null) return;
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null || user.isLocal == isLocal) return;

    _networkAutomationLogger.info('Setting active server to ${isLocal ? 'local' : 'public'}');
    user.update(newIsLocal: isLocal);
    _schedulePlayOnReconnect();
  }, fireImmediately: true);

  container.listen(setOfflineModeProvider, (_, isOffline) {
    if (isOffline == null || isOffline == FinampSettingsHelper.finampSettings.isOffline) return;
    _networkAutomationLogger.info('Setting offline mode to $isOffline');
    GlobalSnackbar.message(
      (context) => AppLocalizations.of(context)!.autoOfflineNotification(isOffline ? 'enabled' : 'disabled'),
    );
    FinampSetters.setIsOffline(isOffline);
  }, fireImmediately: true);

  container.listen(networkConnectivityProvider, (_, value) {
    final state = value.value;
    if (state == null) return;

    if (state != FinampConnectivityState.localNetwork) {
      final activeDownloads = _getDownloads();
      if (activeDownloads > 0) {
        if (state == FinampConnectivityState.none) {
          GlobalSnackbar.message((context) => AppLocalizations.of(context)!.downloadPaused);
        } else if ((Platform.isAndroid || Platform.isIOS) &&
            FinampSettingsHelper.finampSettings.requireWifiForDownloads) {
          GlobalSnackbar.message((context) => AppLocalizations.of(context)!.downloadPaused);
        }
      }
    }

    // Reconnect after every usable transport transition, including a return
    // from mobile data to Wi-Fi where the selected URL may not change.
    if (state != FinampConnectivityState.none) {
      _schedulePlayOnReconnect();
    }
  }, fireImmediately: true);
}

int _getDownloads() {
  final downloadsService = GetIt.instance<DownloadsService>();
  downloadsService.updateDownloadCounts();
  return downloadsService.downloadCounts['sync']! +
      downloadsService.downloadStatuses[DownloadItemState.enqueued]! +
      downloadsService.downloadStatuses[DownloadItemState.downloading]!;
}

Future<void> _reconnectPlayOnService() async {
  final playOnService = GetIt.instance<PlayOnService>();
  if (_latestConnectivity.contains(ConnectivityResult.none)) {
    playOnService.closeListener();
    return;
  }
  await playOnService.reconnectAfterNetworkChange();
}

void _schedulePlayOnReconnect() {
  _playOnReconnectRetry?.cancel();
  _playOnReconnectRetry = Timer(Duration.zero, () {
    _playOnReconnectRetry = null;
    unawaited(_reconnectPlayOnService());
  });
}

@riverpod
Future<FinampConnectivityState> networkConnectivity(Ref ref) async {
  // Avoid toggling offline mode for the brief transport gap that some
  // platforms report while handing Wi-Fi over to mobile data.
  await Future<void>.delayed(const Duration(seconds: 7));
  final results = _latestConnectivity;
  if (results.contains(ConnectivityResult.ethernet) || results.contains(ConnectivityResult.wifi)) {
    return FinampConnectivityState.localNetwork;
  }
  if (results.contains(ConnectivityResult.none)) return FinampConnectivityState.none;
  return FinampConnectivityState.cellular;
}

@riverpod
Future<bool> serverReachability(Ref ref, ServerPingType target) {
  final api = GetIt.instance<JellyfinApiHelper>();
  switch (target) {
    case ServerPingType.local:
      // Never probe a private address after Android has reported that the
      // local transport is gone: select the public endpoint immediately.
      final localTransport =
          _latestConnectivity.contains(ConnectivityResult.ethernet) ||
          _latestConnectivity.contains(ConnectivityResult.wifi);
      return localTransport ? api.pingLocalServer() : Future.value(false);
    case ServerPingType.remote:
      return api.pingPublicServer();
    case ServerPingType.active:
      return api.pingActiveServer();
  }
}

@riverpod
bool? setOfflineMode(Ref ref) {
  if (!ref.watch(finampSettingsProvider.autoOfflineListenerActive)) return null;

  switch (ref.watch(finampSettingsProvider.autoOffline)) {
    case AutoOfflineOption.disconnected:
      final state = ref.watch(networkConnectivityProvider).value;
      return state == null ? null : state == FinampConnectivityState.none;
    case AutoOfflineOption.network:
      final state = ref.watch(networkConnectivityProvider).value;
      return state == null ? null : state != FinampConnectivityState.localNetwork;
    case AutoOfflineOption.unreachable:
      final reachable = ref.watch(serverReachabilityProvider(ServerPingType.active)).value;
      return reachable == null ? null : !reachable;
    case AutoOfflineOption.disabled:
      return null;
  }
}

@riverpod
bool? setLocalUrl(Ref ref) {
  final user = ref.watch(FinampUserHelper.finampCurrentUserProvider);
  if (user == null) return null;
  if (!user.preferLocalNetwork) return false;
  // Android can report a momentary `none` while it moves to mobile data. Do
  // not trigger a queue reload on a route that cannot work yet; the following
  // usable transport event selects the public or local endpoint.
  if (_latestConnectivity.contains(ConnectivityResult.none)) return null;
  return ref.watch(serverReachabilityProvider(ServerPingType.local)).value;
}

Future<void> _onConnectivityChange(List<ConnectivityResult> connections) async {
  _networkAutomationLogger.info('Network change: ${connections.join(', ')}');
  _latestConnectivity = connections;

  // Drop stale pooled sockets straight away. The background worker handles
  // this as a normal task, so a reset can run while an older request unwinds.
  unawaited(GetIt.instance<JellyfinApiHelper>().resetNetworkConnections());

  final container = GetIt.instance<ProviderContainer>();
  // Invalidate the active family instance explicitly. Invalidating only the
  // family root does not reliably refresh an already-listened-to argument.
  container.invalidate(serverReachabilityProvider(ServerPingType.local));
  container.invalidate(setLocalUrlProvider);
  container.invalidate(networkConnectivityProvider);

  _localReachabilityRetry?.cancel();
  final hasLocalTransport =
      connections.contains(ConnectivityResult.ethernet) || connections.contains(ConnectivityResult.wifi);
  if (hasLocalTransport) {
    _localReachabilityRetry = Timer(_localReachabilityRetryDelay, () {
      _networkAutomationLogger.fine('Retrying local-server reachability after network hand-off');
      container.invalidate(serverReachabilityProvider(ServerPingType.local));
    });
  }

  if (connections.contains(ConnectivityResult.none)) {
    _playOnReconnectRetry?.cancel();
    GetIt.instance<PlayOnService>().closeListener();
  }
}
