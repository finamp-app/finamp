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

enum NetworkQueueReloadAction { none, automatic, manualPrompt, manualLossLimitExceeded }

NetworkQueueReloadAction decideNetworkQueueReloadAction(SourceChangeType event, FinampQueueInfo queueInfo) {
  // Returning online does not alter the active queue: Finamp already prefers
  // downloaded tracks, so there is nothing to reload.
  if (event == SourceChangeType.toOnline) return NetworkQueueReloadAction.none;

  if (queueInfo.trackCount == 0 || queueInfo.undownloadedTracks == 0) {
    return NetworkQueueReloadAction.none;
  }

  final settings = FinampSettingsHelper.finampSettings;
  if (!settings.autoReloadQueue) return NetworkQueueReloadAction.manualPrompt;
  if (event != SourceChangeType.toOffline) return NetworkQueueReloadAction.automatic;

  final maximumDroppedTracksPercentage = settings.autoReloadQueueMaxDroppedTracksPercentage.clamp(0, 100).toInt();
  final canReloadAutomatically =
      queueInfo.undownloadedTracks * 100 <= queueInfo.trackCount * maximumDroppedTracksPercentage;
  return canReloadAutomatically ? NetworkQueueReloadAction.automatic : NetworkQueueReloadAction.manualLossLimitExceeded;
}

class DataSourceService {
  // A URL change can be delivered by a provider while Flutter is building a
  // frame. Queue requests must run after that synchronous callback, but must
  // not wait for a rendered frame: the app can be in the background.
  static Future<void>? _scheduledQueueReload;

  /// Returns whether entering Offline Mode will display an actionable queue
  /// reload prompt, which already explains the mode change.
  static bool willShowQueueReloadPrompt({required bool isOffline}) {
    if (!isOffline || !GetIt.instance.isRegistered<QueueService>()) return false;

    final queueInfo = GetIt.instance<QueueService>().getQueue();
    final action = decideNetworkQueueReloadAction(SourceChangeType.toOffline, queueInfo);
    return action == NetworkQueueReloadAction.manualPrompt ||
        action == NetworkQueueReloadAction.manualLossLimitExceeded;
  }

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
      final action = decideNetworkQueueReloadAction(event, queueInfo);
      if (action == NetworkQueueReloadAction.none) return;
      if (action == NetworkQueueReloadAction.automatic) {
        await _reloadQueueOutsideProviderCallback(queueService);
        return;
      }

      if (action == NetworkQueueReloadAction.manualLossLimitExceeded) {
        _dataSourceServiceLogger.info("Skipping automatic offline queue reload: too many tracks would be removed");
      }

      GlobalSnackbar.message(
        (context) {
          final reloadPrompt = AppLocalizations.of(context)!.autoReloadPrompt(SourceChangeGenericType.network.name);
          final reloadPromptMissingTracks = AppLocalizations.of(
            context,
          )!.autoReloadPromptMissingTracks(queueInfo.undownloadedTracks);
          if (event == SourceChangeType.toOffline) {
            // Warn about tracks unavailable after an offline reload, before it happens.
            if (action == NetworkQueueReloadAction.manualLossLimitExceeded) {
              final roundedPercentage = (queueInfo.undownloadedTracks * 100 / queueInfo.trackCount).round();
              final removedPercentage = queueInfo.undownloadedTracks == queueInfo.trackCount
                  ? 100
                  : roundedPercentage.clamp(1, 99);
              final lossLimitExplanation = AppLocalizations.of(
                context,
              )!.autoReloadPromptLossLimitExceeded(queueInfo.undownloadedTracks, removedPercentage);
              return "$reloadPrompt. $lossLimitExplanation";
            }
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

    switch (event) {
      case SourceChangeType.toLocalUrl:
      case SourceChangeType.toRemoteUrl:
        // A URL hand-off is not a queue source change while Offline Mode is
        // active: preserve the archived/pre-offline queue until the mode clears.
        if (FinampSettingsHelper.finampSettings.isOffline) {
          _dataSourceServiceLogger.info("Skipping URL-triggered queue reload while Offline Mode is active");
          break;
        }
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
        if (queueInfo.trackCount == 0) break;
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
