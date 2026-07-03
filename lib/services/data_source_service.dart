import 'dart:core';
import 'dart:io';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'finamp_settings_helper.dart';

Logger _dataSourceServiceLogger = Logger("Data Source Service");

enum SourceChangeGenericType { network, transcoding }

enum SourceChangeType { toLocalUrl, toRemoteUrl, toOffline, toOnline, toDirectPlay, toTranscoding }

class DataSourceService {
  static void create() {
    final FinampUserHelper finampUserHelper = GetIt.instance<FinampUserHelper>();
    final ref = GetIt.instance<ProviderContainer>();

    ref.listen(finampSettingsProvider.isOffline, (_, isOffline) {
      if (isOffline) {
        _dataSourceServiceLogger.info("Offline Mode Enabled");
      } else {
        _dataSourceServiceLogger.info("Offline Mode Disabled");
      }
      _onDataSourceChange(isOffline ? SourceChangeType.toOffline : SourceChangeType.toOnline);
    });

    // We only have track codec info as playing approaches, so without android just-in-time uris
    // we just watch the generic transcode profile without codec considered.
    ref.listen(activeTranscodingProfile(null), (_, profile) {
      // TODO clean all this up
      bool shouldTranscode = profile.format != FinampTranscodingStreamingFormat.original;
      if (shouldTranscode) {
        _dataSourceServiceLogger.info("Transcoding Enabled");
      } else {
        _dataSourceServiceLogger.info("Transcoding Disabled");
      }
      _onDataSourceChange(shouldTranscode ? SourceChangeType.toTranscoding : SourceChangeType.toDirectPlay);
    });

    ref.listen(FinampUserHelper.finampCurrentUserProvider.select((user) => user?.baseURL), (_, newUrl) {
      _dataSourceServiceLogger.info("Base URL Changed: $newUrl");
      bool isLocalUrl = finampUserHelper.currentUser?.isLocal ?? false;
      _onDataSourceChange(isLocalUrl ? SourceChangeType.toLocalUrl : SourceChangeType.toRemoteUrl);
    });
  }

  static Future<void> _onDataSourceChange(SourceChangeType event) async {
    if (!GetIt.instance.isRegistered<QueueService>()) return;
    // Android should auto-update queue items as they play
    if (Platform.isAndroid && event != SourceChangeType.toOffline) return;
    final QueueService queueService = GetIt.instance<QueueService>();
    _dataSourceServiceLogger.finest("Connectivity Change Triggered, event is '$event'");

    final queueInfo = queueService.getQueue();

    if (queueInfo.trackCount > 0) {
      switch (event) {
        case SourceChangeType.toLocalUrl:
        case SourceChangeType.toRemoteUrl:
        case SourceChangeType.toOffline:
          if (queueInfo.undownloadedTracks > 0) {
            if (FinampSettingsHelper.finampSettings.autoReloadQueue) {
              await queueService.reloadQueue();
            } else {
              GlobalSnackbar.message(
                (context) {
                  final reloadPrompt = AppLocalizations.of(
                    context,
                  )!.autoReloadPrompt(SourceChangeGenericType.network.name);
                  final reloadPromptMissingTracks = AppLocalizations.of(
                    context,
                  )!.autoReloadPromptMissingTracks(queueInfo.undownloadedTracks);
                  if (event == SourceChangeType.toOffline && queueInfo.undownloadedTracks > 0) {
                    // we want to warn the user about undownloaded tracks that won't be available after reloading the queue, before they actually reload
                    return "$reloadPrompt. $reloadPromptMissingTracks";
                  } else {
                    return reloadPrompt;
                  }
                },
                action: (context) => SnackBarAction(
                  label: AppLocalizations.of(context)!.autoReloadPromptReloadButton,
                  onPressed: () {
                    // archived queues are not overwritten and can always be restored again
                    bool archivalNeeded = event == SourceChangeType.toOffline;
                    queueService.reloadQueue(archiveQueue: archivalNeeded);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
                isConfirmation: false,
              );
            }
          }
          break;
        case SourceChangeType.toOnline:
          // nop, queue won't change since Finamp prefers downloaded data anyway
          break;
        case SourceChangeType.toDirectPlay:
        case SourceChangeType.toTranscoding:
          // Transcoding profile changes have no effect while offline
          if (FinampSettingsHelper.finampSettings.isOffline) break;
          final queueInfo = queueService.getQueue();
          final transcodingItemsExist = queueInfo.fullQueue.any((item) => item.isTranscodedStream);
          if (event == SourceChangeType.toTranscoding || transcodingItemsExist) {
            if (FinampSettingsHelper.finampSettings.autoReloadQueue) {
              await queueService.reloadQueue();
            } else {
              GlobalSnackbar.message(
                (context) => AppLocalizations.of(context)!.autoReloadPrompt(SourceChangeGenericType.transcoding.name),
                action: (context) => SnackBarAction(
                  label: AppLocalizations.of(context)!.autoReloadPromptReloadButton,
                  onPressed: () {
                    queueService.reloadQueue(archiveQueue: false);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
                isConfirmation: false,
              );
            }
          }
          break;
      }
    }
  }

  static final activeTranscodingProfile = Provider.family<StreamingTranscodingConfig, String?>((
    Ref ref,
    String? codec,
  ) {
    StreamingTranscodingConfig? watch(ProviderListenable<String> configNameProvider) {
      final configName = ref.watch(configNameProvider);
      return ref.watch(finampSettingsProvider.streamingTranscodeConfigs(configName));
    }

    if (ref.watch(finampSettingsProvider.forceTranscode)) {
      return watch(finampSettingsProvider.forcedTranscodeConfig) ?? StreamingTranscodingPreset.losslessPreset;
    }
    final validPresets = [watch(finampSettingsProvider.defaultTranscodeConfig)];
    final user = ref.watch(FinampUserHelper.finampCurrentUserProvider);
    if (user != null && user.preferLocalNetwork && !user.isLocal) {
      validPresets.add(watch(finampSettingsProvider.remoteTranscodeConfig));
    }
    if (ref.watch(networkConnectivityProvider).value == FinampConnectivityState.cellular) {
      validPresets.add(watch(finampSettingsProvider.cellularTranscodeConfig));
    }
    // TODO should we just be checking bitrate?
    // IF so, would it make sense to allow configuring bitrate cutoff?
    if (codec == "flac") {
      validPresets.add(watch(finampSettingsProvider.flacTranscodeConfig));
    }
    // TODO can we validate codecs are readable somehow?
    // Use transcode config with lowest effective bitrate
    var output = StreamingTranscodingPreset.originalPreset;
    for (final config in validPresets) {
      if (config != null && config.effectiveBitrate < output.effectiveBitrate) {
        output = config;
      }
    }
    return output;
  });
}
