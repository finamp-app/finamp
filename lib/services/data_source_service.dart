import 'dart:core';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
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

    // TODO create active transcode profile provider, just listen to that

    /*ref.listen(finampSettingsProvider.shouldTranscode, (_, shouldTranscode) {
      if (shouldTranscode) {
        _dataSourceServiceLogger.info("Transcoding Enabled");
      } else {
        _dataSourceServiceLogger.info("Transcoding Disabled");
      }
      _onDataSourceChange(shouldTranscode ? SourceChangeType.toTranscoding : SourceChangeType.toDirectPlay);
    });

    ref.listen(finampSettingsProvider.transcodingStreamingFormat, (_, transcodingStreamingFormat) {
      if (FinampSettingsHelper.finampSettings.shouldTranscode) {
        _dataSourceServiceLogger.info("Transcoding Streaming Format Changed: $transcodingStreamingFormat");
        _onDataSourceChange(SourceChangeType.toTranscoding);
      }
    });

    ref.listen(finampSettingsProvider.transcodeBitrate, (_, transcodeBitrate) {
      if (FinampSettingsHelper.finampSettings.shouldTranscode) {
        _dataSourceServiceLogger.info("Transcoding Bitrate Changed: $transcodeBitrate");
        _onDataSourceChange(SourceChangeType.toTranscoding);
      }
    });
    */

    ref.listen(FinampUserHelper.finampCurrentUserProvider.select((user) => user.value?.baseURL), (_, newUrl) {
      _dataSourceServiceLogger.info("Base URL Changed: $newUrl");
      bool isLocalUrl = finampUserHelper.currentUser?.isLocal ?? false;
      _onDataSourceChange(isLocalUrl ? SourceChangeType.toLocalUrl : SourceChangeType.toRemoteUrl);
    });
  }

  static Future<void> _onDataSourceChange(SourceChangeType event) async {
    if (!GetIt.instance.isRegistered<QueueService>()) return;
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

  static StreamingTranscodingConfig activeTranscodingProfile() {
    final settings = FinampSettingsHelper.finampSettings;
    final allConfigs = settings.streamingTranscodeConfigs;
    if (FinampSettingsHelper.finampSettings.forceTranscode) {
      return allConfigs[settings.forcedTranscodeConfig] ?? StreamingTranscodingPreset.losslessPreset;
    }
    final validPresets = [allConfigs[settings.defaultTranscodeConfig]];
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user != null && user.preferLocalNetwork && !user.isLocal) {
      validPresets.add(allConfigs[settings.remoteTranscodeConfig]);
    }
    // TODO integrate with network manager.  Need to make sure it runs if cellularTranscodeConfig is tighter than default?
    if (true) {
      validPresets.add(allConfigs[settings.cellularTranscodeConfig]);
    }
    // Use transcode config with lowest effective bitrate
    var output = StreamingTranscodingPreset.originalPreset;
    for (final config in validPresets) {
      if (config != null && config.effectiveBitrate < output.effectiveBitrate) {
        output = config;
      }
    }
    return output;
  }
}
