import 'dart:async';

import 'package:finamp/components/PlayerScreen/player_buttons_loop_mode.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_playback_order.dart';
import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/components/audio_fade_progress_visualizer_container.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/utils/locale_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../../services/media_state_stream.dart';
import '../../services/music_player_background_task.dart';

class PlayerButtons extends StatelessWidget {
  const PlayerButtons(this.controller, {super.key});

  final PlayerHideableController controller;

  @override
  Widget build(BuildContext context) {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

    return StreamBuilder<MediaState>(
      stream: mediaStateStream,
      initialData: MediaState(
        audioHandler.mediaItem.valueOrNull,
        audioHandler.playbackState.value,
        audioHandler.fadeState.value,
      ),
      builder: (context, snapshot) {
        final mediaState = snapshot.data!;
        final playbackState = mediaState.playbackState;
        final fadeState = mediaState.fadeState;

        return Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          textDirection: TextDirection.ltr,
          children: [
            if (controller.shouldShow(PlayerHideable.loopShuffleButtons)) PlayerButtonsPlaybackOrder(),
            Semantics.fromProperties(
              properties: SemanticsProperties(
                label: AppLocalizations.of(context)!.skipToPreviousTrackButtonTooltip,
                button: true,
              ),
              container: true,
              excludeSemantics: true,
              child: IconButton(
                tooltip: getStringComponentsInLocaleOrder(context, [
                  AppLocalizations.of(context)!.skipToPreviousTrackButtonTooltip,
                  "(${GlobalShortcuts.getDisplay(SkipToPreviousIntent)})",
                ], separator: "\n"),
                icon: const Icon(TablerIcons.player_skip_back),
                onPressed: () async {
                  FeedbackHelper.feedback(FeedbackType.light);
                  await audioHandler.skipToPrevious();
                },
              ),
            ),
            Semantics.fromProperties(
              properties: SemanticsProperties(
                label: AppLocalizations.of(context)!.togglePlaybackButtonTooltip,
                button: true,
              ),
              container: true,
              excludeSemantics: true,
              child: _RoundedIconButton(
                width: controller.shouldShow(PlayerHideable.bigPlayButton) ? 62 : 48,
                height: controller.shouldShow(PlayerHideable.bigPlayButton) ? 62 : 48,
                borderRadius: BorderRadius.circular(controller.shouldShow(PlayerHideable.bigPlayButton) ? 16 : 12),
                onTap: () {
                  FeedbackHelper.feedback(FeedbackType.light);
                  unawaited(audioHandler.togglePlayback());
                },
                label: AppLocalizations.of(context)!.togglePlaybackButtonTooltip,
                tooltip: getStringComponentsInLocaleOrder(context, [
                  AppLocalizations.of(context)!.togglePlaybackButtonTooltip,
                  "(${GlobalShortcuts.getDisplay(TogglePlaybackIntent)})",
                ], separator: "\n"),
                icon: AudioFadeProgressVisualizerContainer(
                  key: const Key("PlayerButtonAudioFadeProgressVisualizer"),
                  borderRadius: BorderRadius.all(
                    Radius.circular(controller.shouldShow(PlayerHideable.bigPlayButton) ? 16 : 12),
                  ),
                  color: IconTheme.of(context).color!.withAlpha(128),
                  child: Icon(
                    playbackState.playing
                        ? fadeState.fadeDirection != FadeDirection.fadeOut
                              ? TablerIcons.player_pause
                              : TablerIcons.player_play
                        : TablerIcons.player_play,
                    size: 32,
                  ),
                ),
              ),
            ),
            Semantics.fromProperties(
              properties: SemanticsProperties(
                label: AppLocalizations.of(context)!.skipToNextTrackButtonTooltip,
                button: true,
              ),
              container: true,
              excludeSemantics: true,
              child: IconButton(
                tooltip: getStringComponentsInLocaleOrder(context, [
                  AppLocalizations.of(context)!.skipToNextTrackButtonTooltip,
                  "(${GlobalShortcuts.getDisplay(SkipToNextIntent)})",
                ], separator: "\n"),
                icon: const Icon(TablerIcons.player_skip_forward),
                onPressed: () async {
                  FeedbackHelper.feedback(FeedbackType.light);
                  await audioHandler.skipToNext();
                },
              ),
            ),
            if (controller.shouldShow(PlayerHideable.loopShuffleButtons)) PlayerButtonsLoopMode(),
          ],
        );
      },
    );
  }
}

class _RoundedIconButton extends StatelessWidget {
  const _RoundedIconButton({
    required this.icon,
    required this.label,
    this.tooltip,
    this.borderRadius,
    this.width = 48,
    this.height = 48,
    this.onTap,
  });

  final Widget icon;
  final String? label;
  final String? tooltip;
  final BorderRadius? borderRadius;
  final double width;
  final double height;
  final VoidCallback? onTap;

  Widget _addDropShadow(Icon icon, BuildContext context) {
    // If only Icon had a .copyWith() function lol
    return Icon(
      icon.icon,
      color: icon.color,
      key: icon.key,
      semanticLabel: icon.semanticLabel,
      size: icon.size,
      textDirection: icon.textDirection,
      shadows:
          icon.shadows ??
          [
            BoxShadow(
              blurRadius: 2,
              offset: const Offset(0, 2),
              color: (icon.color ?? IconTheme.of(context).color)!.withOpacity(0.25),
            ),
          ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final actualBorderRadius = borderRadius ?? BorderRadius.circular(height);
    final actualIcon = icon is Icon ? _addDropShadow(icon as Icon, context) : icon;
    final button = SizedBox(
      width: width,
      height: height,
      child: Material(
        borderRadius: actualBorderRadius,
        color: IconTheme.of(context).color!.withOpacity(0.15),
        child: InkWell(borderRadius: actualBorderRadius, onTap: onTap, child: actualIcon),
      ),
    );

    return Semantics(
      excludeSemantics: true,
      label: label,
      tooltip: tooltip,
      hint: tooltip,
      button: true,
      child: tooltip != null ? Tooltip(message: tooltip!, triggerMode: TooltipTriggerMode.tap, child: button) : button,
    );
  }
}
