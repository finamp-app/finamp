import 'dart:async';
import 'dart:core';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
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
  // A URL change can be delivered by a provider while Flutter is building a
  // frame. Queue requests must run after that synchronous callback, but must
  // not wait for a rendered frame: the app can be in the background.
  static Future<void>? _scheduledQueueReload;

  static Future<void> _reloadQueueOutsideProviderCallback(QueueService queueService) {
    final currentReload = _scheduledQueueReload;
    if (currentReload != null) return currentReload;

    late final Future<void> reload;
    reload = Future<void>.delayed(Duration.zero).then((_) => queueService.reloadQueue()).whenComplete(() {
      if (identical(_scheduledQueueReload, reload)) {
        _scheduledQueueReload = null;
      }
    });
    _scheduledQueueReload = reload;
    return reload;
  }

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

    ref.listen(finampSettingsProvider.shouldTranscode, (_, shouldTranscode) {
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

    ref.listen(FinampUserHelper.finampCurrentUserProvider.select((user) => user?.baseURL), (_, newUrl) {
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

    Future<void> handleNetworkQueueReload() async {
      if (queueInfo.undownloadedTracks == 0) return;
      if (FinampSettingsHelper.finampSettings.autoReloadQueue) {
        await _reloadQueueOutsideProviderCallback(queueService);
        return;
      }

      GlobalSnackbar.message(
        (context) {
          final reloadPrompt = AppLocalizations.of(context)!.autoReloadPrompt(SourceChangeGenericType.network.name);
          final reloadPromptMissingTracks = AppLocalizations.of(
            context,
          )!.autoReloadPromptMissingTracks(queueInfo.undownloadedTracks);
          if (event == SourceChangeType.toOffline) {
            // Warn about tracks unavailable after an offline reload, before it happens.
            return "$reloadPrompt. $reloadPromptMissingTracks";
          }
          return reloadPrompt;
        },
        action: (context) => SnackBarAction(
          label: AppLocalizations.of(context)!.autoReloadPromptReloadButton,
          onPressed: () {
            // Archived queues are not overwritten and can always be restored.
            queueService.reloadQueue(archiveQueue: event == SourceChangeType.toOffline);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        isConfirmation: false,
      );
    }

    if (queueInfo.trackCount > 0) {
      switch (event) {
        case SourceChangeType.toLocalUrl:
        case SourceChangeType.toRemoteUrl:
          await handleNetworkQueueReload();
          break;
        case SourceChangeType.toOffline:
          await handleNetworkQueueReload();
          break;
        case SourceChangeType.toOnline:
          // nop, queue won't change since Finamp prefers downloaded data anyway
          break;
        case SourceChangeType.toDirectPlay:
        case SourceChangeType.toTranscoding:
          final queueInfo = queueService.getQueue();
          final transcodingItemsExist = queueInfo.fullQueue.any((item) => item.item.extras?["shouldTranscode"] == true);
          if (event == SourceChangeType.toTranscoding || transcodingItemsExist) {
            if (FinampSettingsHelper.finampSettings.autoReloadQueue) {
              await _reloadQueueOutsideProviderCallback(queueService);
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
}
