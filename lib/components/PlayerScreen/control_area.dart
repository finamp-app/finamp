import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/services/animated_music_service.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';

import 'feature_chips.dart';
import 'player_buttons.dart';
import 'progress_slider.dart';

class ControlArea extends StatelessWidget {
  const ControlArea(this.controller, {this.extrasCollapsed = false, this.animateCollapse = false, super.key});

  final PlayerHideableController controller;
  final bool extrasCollapsed;
  final bool animateCollapse;

  @override
  Widget build(BuildContext context) {
    Widget progressSlider = const ProgressSlider();
    if (isDesktop) {
      progressSlider = Tooltip(
        message: AppLocalizations.of(context)!.seekControlHint(
          "${GlobalShortcuts.getDisplay(SeekForwardIntent)} / "
          "${GlobalShortcuts.getDisplay(SeekBackwardIntent)}",
        ),
        triggerMode: TooltipTriggerMode.tap,
        child: progressSlider,
      );
    }

    final showFeatures = controller.shouldShow(PlayerHideable.features) && !extrasCollapsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.shouldShow(PlayerHideable.features) || extrasCollapsed)
          CollapsingPlayerSlot(visible: showFeatures, animate: animateCollapse, child: const FeatureChips()),
        if (controller.shouldShow(PlayerHideable.progressSlider) || extrasCollapsed) progressSlider,
        CollapsingPlayerSlot(visible: !extrasCollapsed, animate: animateCollapse, child: PlayerButtons(controller)),
      ],
    );
  }
}

class CollapsingPlayerSlot extends StatelessWidget {
  const CollapsingPlayerSlot({super.key, required this.visible, required this.animate, required this.child});

  final bool visible;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = animate ? animatedMusicFadeDurationOf(context) : Duration.zero;
    return ClipRect(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedAlign(
          duration: duration,
          curve: animatedMusicFadeCurve,
          alignment: Alignment.topCenter,
          heightFactor: visible ? 1 : 0,
          child: AnimatedOpacity(
            duration: duration,
            curve: animatedMusicFadeCurve,
            opacity: visible ? 1 : 0,
            child: child,
          ),
        ),
      ),
    );
  }
}
