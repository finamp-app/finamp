import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/playon_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/finamp_models.dart';
import 'finamp_settings_helper.dart';

part 'network_manager.g.dart';

Logger _networkAutomationLogger = Logger("Network Automation");

enum FinampConnectivityState { localNetwork, cellular, none }

enum ServerPingType { local, remote, active }

// The latest connectivity results, updated by _onConnectivityChange
late List<ConnectivityResult> _latestConnectivity;

Future<void> startNetworkAutomation() async {
  ProviderContainer container = GetIt.instance<ProviderContainer>();

  Connectivity().onConnectivityChanged.listen(_onConnectivityChange);
  _latestConnectivity = await Connectivity().checkConnectivity();

  container.listen(setLocalUrlProvider, (_, value) {
    if (value == null) return;
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null || user.isLocal == value) return;
    _networkAutomationLogger.info("Setting user isLocal to $value");
    user.update(newIsLocal: value);
    _reconnectPlayOnService();
  });
  container.listen(setOfflineModeProvider, (_, value) {
    if (value == null || value == FinampSettingsHelper.finampSettings.isOffline) return;
    _networkAutomationLogger.info("Setting isOffline to $value");
    GlobalSnackbar.message(
      (context) => AppLocalizations.of(context)!.autoOfflineNotification(value ? "enabled" : "disabled"),
    );
    FinampSetters.setIsOffline(value);
  });
  // Alert user about paused downloads
  container.listen(networkConnectivityProvider, (_, value) {
    final state = value.value;
    if (state == null || state == FinampConnectivityState.localNetwork) return;

    final activeDownloads = _getDownloads();
    if (activeDownloads == 0) return;

    if (state == FinampConnectivityState.none) {
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.downloadPaused);
      return;
    }

    // desktop doesn't have this setting
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    if (FinampSettingsHelper.finampSettings.requireWifiForDownloads) {
      GlobalSnackbar.message((context) => AppLocalizations.of(context)!.downloadPaused);
    }
  });
}

@riverpod
Future<FinampConnectivityState> networkConnectivity(Ref ref) async {
  // Wait 7 seconds to avoid firing for temporary network blips or incidental errors in connectivity
  // state that occur on iso/mac.  If network state changes during this waiting period, this current build of the provider
  // will be invalidated and the final result will be ignored.
  await Future<void>.delayed(Duration(seconds: 7));
  final results = _latestConnectivity;
  if (results.contains(ConnectivityResult.ethernet) || results.contains(ConnectivityResult.wifi)) {
    return FinampConnectivityState.localNetwork;
  }
  if (results.contains(ConnectivityResult.none)) {
    return FinampConnectivityState.none;
  }
  return FinampConnectivityState.cellular;
}

@riverpod
Future<bool?> serverReachability(Ref ref, ServerPingType target) {
  final user = GetIt.instance<FinampUserHelper>().currentUser;
  if (user == null) return Future.value(null);
  // All pings implicitly rely on the current user
  switch (target) {
    case ServerPingType.local:
      return GetIt.instance<JellyfinApiHelper>().pingLocalServer();
    case ServerPingType.remote:
      return GetIt.instance<JellyfinApiHelper>().pingPublicServer();
    case ServerPingType.active:
      return GetIt.instance<JellyfinApiHelper>().pingActiveServer();
  }
}

@riverpod
bool? setOfflineMode(Ref ref) {
  if (!ref.watch(finampSettingsProvider.autoOfflineListenerActive)) {
    return null;
  }
  switch (ref.watch(finampSettingsProvider.autoOffline)) {
    case AutoOfflineOption.disconnected:
      final networkStatus = ref.watch(networkConnectivityProvider).value;
      if (networkStatus == null) return null;
      return networkStatus == FinampConnectivityState.none;
    case AutoOfflineOption.network:
      final networkStatus = ref.watch(networkConnectivityProvider).value;
      if (networkStatus == null) return null;
      return networkStatus != FinampConnectivityState.localNetwork;
    case AutoOfflineOption.unreachable:
      final serverReachability = ref.watch(serverReachabilityProvider(ServerPingType.active)).value;
      return serverReachability == null ? null : !serverReachability;
    case AutoOfflineOption.disabled:
      return null;
  }
}

@riverpod
bool? setLocalUrl(Ref ref) {
  final user = ref.watch(FinampUserHelper.finampCurrentUserProvider).value;
  if (user == null) return null;
  if (!user.preferLocalNetwork) return false;
  return ref.watch(serverReachabilityProvider(ServerPingType.local)).value;
}

Future<void> _onConnectivityChange(List<ConnectivityResult> connections) async {
  _networkAutomationLogger.finest("Network Change: ${connections.map((element) => element.toString()).join(", ")}");
  _latestConnectivity = connections;
  ProviderContainer container = GetIt.instance<ProviderContainer>();
  container.invalidate(serverReachabilityProvider);
  container.invalidate(networkConnectivityProvider);
}

int _getDownloads() {
  final downloadsService = GetIt.instance<DownloadsService>();
  downloadsService.updateDownloadCounts();

  final nodesSyncing = downloadsService.downloadCounts["sync"]!;
  final downloadingEnqueued = downloadsService.downloadStatuses[DownloadItemState.enqueued]!;
  final downloadingRunning = downloadsService.downloadStatuses[DownloadItemState.downloading]!;

  final activeDownloads = nodesSyncing + downloadingEnqueued + downloadingRunning;
  return activeDownloads;
}

void _reconnectPlayOnService() async {
  final playOnService = GetIt.instance<PlayOnService>();
  playOnService.closeListener();
  // TODO this was previously gated behind a check if network state was not none.  I think that's bad logic?
  // It seems like this socket gets disconnected when the app gets backgrounded, at least while not playing - is this showing as a full network disconnect?
  // Hopefully it isn't, because that would be wrecking autooffline mode with auto-reload queue.
  await playOnService.startListener();
}
