import 'dart:async';

import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/remote_session_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class TogglePlaybackIntent extends Intent {
  const TogglePlaybackIntent();
}

class SkipToNextIntent extends Intent {
  const SkipToNextIntent();
}

class SkipToPreviousIntent extends Intent {
  const SkipToPreviousIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}

class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

class ToggleLoopModeIntent extends Intent {
  const ToggleLoopModeIntent();
}

class TogglePlaybackOrderIntent extends Intent {
  const TogglePlaybackOrderIntent();
}

Map<Type, Action<Intent>> getMusicControlActions() {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final queueService = GetIt.instance<QueueService>();
  final remoteSession = GetIt.instance<RemoteSessionService>();

  return {
    TogglePlaybackIntent: _MusicControlTextFieldSafeAction<TogglePlaybackIntent>(
      onInvoke: (_) {
        if (remoteSession.isRemote) {
          unawaited(remoteSession.playPause());
        } else {
          unawaited(audioHandler.togglePlayback());
        }
        return null;
      },
    ),
    SkipToNextIntent: _MusicControlAction<SkipToNextIntent>(
      onInvoke: (_) {
        if (remoteSession.isRemote) {
          remoteSession.next();
        } else {
          audioHandler.skipToNext();
        }
        GlobalSnackbar.message((context) => AppLocalizations.of(context)!.skipToNextTrackButtonTooltip);
        return null;
      },
    ),
    SkipToPreviousIntent: _MusicControlAction<SkipToPreviousIntent>(
      onInvoke: (_) {
        if (remoteSession.isRemote) {
          remoteSession.previous();
        } else {
          audioHandler.skipToPrevious();
        }
        GlobalSnackbar.message((context) => AppLocalizations.of(context)!.skipToPreviousTrackButtonTooltip);
        return null;
      },
    ),
    SeekForwardIntent: _MusicControlTextFieldSafeAction<SeekForwardIntent>(
      onInvoke: (_) {
        if (remoteSession.isRemote) {
          final base = remoteSession.remotePlaybackState?.position ?? Duration.zero;
          remoteSession.seek(base + const Duration(seconds: 30));
        } else {
          audioHandler.seek(audioHandler.playbackPosition + const Duration(seconds: 30));
        }
        return null;
      },
    ),
    SeekBackwardIntent: _MusicControlTextFieldSafeAction<SeekBackwardIntent>(
      onInvoke: (_) {
        final current = remoteSession.isRemote
            ? (remoteSession.remotePlaybackState?.position ?? Duration.zero)
            : audioHandler.playbackPosition;
        final target = current < const Duration(seconds: 5) ? Duration.zero : current - const Duration(seconds: 5);
        if (remoteSession.isRemote) {
          remoteSession.seek(target);
        } else {
          audioHandler.seek(target);
        }
        return null;
      },
    ),
    // Volume, loop mode and playback order have no remote equivalent in the
    // Play On command set, so they always act on local playback (Slice D5c).
    VolumeUpIntent: _MusicControlTextFieldSafeAction<VolumeUpIntent>(
      onInvoke: (_) {
        final newVolume = (audioHandler.volume + 0.05).clamp(0.0, 1.0);
        audioHandler.setVolume(newVolume);
        return null;
      },
    ),
    VolumeDownIntent: _MusicControlTextFieldSafeAction<VolumeDownIntent>(
      onInvoke: (_) {
        final newVolume = (audioHandler.volume - 0.05).clamp(0.0, 1.0);
        audioHandler.setVolume(newVolume);
        return null;
      },
    ),
    ToggleLoopModeIntent: _MusicControlTextFieldSafeAction<ToggleLoopModeIntent>(
      onInvoke: (_) {
        queueService.toggleLoopMode();

        GlobalSnackbar.message((context) {
          switch (queueService.loopMode) {
            case FinampLoopMode.all:
              return AppLocalizations.of(context)!.loopModeAllButtonLabel;
            case FinampLoopMode.one:
              return AppLocalizations.of(context)!.loopModeOneButtonLabel;
            case FinampLoopMode.none:
              return AppLocalizations.of(context)!.loopModeNoneButtonLabel;
          }
        });

        return null;
      },
    ),
    TogglePlaybackOrderIntent: _MusicControlTextFieldSafeAction<TogglePlaybackOrderIntent>(
      onInvoke: (_) {
        queueService.togglePlaybackOrder();

        GlobalSnackbar.message((context) {
          switch (queueService.playbackOrder) {
            case FinampPlaybackOrder.linear:
              return AppLocalizations.of(context)!.playbackOrderLinearButtonLabel;
            case FinampPlaybackOrder.shuffled:
              return AppLocalizations.of(context)!.playbackOrderShuffledButtonLabel;
          }
        });

        return null;
      },
    ),
  };
}

class _MusicControlAction<T extends Intent> extends CallbackAction<T> {
  _MusicControlAction({required super.onInvoke});

  @override
  Object? invoke(T intent) {
    if (GetIt.instance<QueueService>().getQueue().currentTrack == null) return null;
    shortcutLogger.info("Invoking shortcut for intent: $intent");
    return super.invoke(intent);
  }
}

class _MusicControlTextFieldSafeAction<T extends Intent> extends _MusicControlAction<T> {
  _MusicControlTextFieldSafeAction({required super.onInvoke});

  @override
  bool consumesKey(T intent) {
    return !_isInTextField();
  }

  @override
  Object? invoke(T intent) {
    if (_isInTextField()) return null;
    shortcutLogger.info("Invoking shortcut for intent: $intent");
    return super.invoke(intent);
  }
}

bool _isInTextField() {
  final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null || primaryFocus.context == null) {
    return false;
  }

  final BuildContext? context = primaryFocus.context;
  if (context == null) {
    return false;
  }

  bool isInTextField = false;

  context.visitAncestorElements((Element element) {
    if (element.widget is TextField || element.widget is TextFormField) {
      isInTextField = true;
      return false;
    }
    return true;
  });

  return isInTextField;
}
