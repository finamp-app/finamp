import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/utils/locale_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class PlayerButtonsPlaybackOrder extends StatelessWidget {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final _queueService = GetIt.instance<QueueService>();

  PlayerButtonsPlaybackOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _queueService.getPlaybackOrderStream(),
      initialData: _queueService.playbackOrder,
      builder: (BuildContext context, snapshot) {
        final shortcutHint = GlobalShortcuts.getDisplay(TogglePlaybackOrderIntent);
        final playbackOrderHint = getLocalizedPlaybackOrder(context, _queueService.playbackOrder);
        return IconButton(
          tooltip: getStringComponentsInLocaleOrder(context, [playbackOrderHint, "($shortcutHint)"], separator: "\n"),
          onPressed: () async {
            FeedbackHelper.feedback(FeedbackType.light);
            await _queueService.togglePlaybackOrder();
          },
          icon: Icon(
            (snapshot.data! == FinampPlaybackOrder.shuffled ? TablerIcons.arrows_shuffle : TablerIcons.arrows_right),
          ),
        );
      },
    );
  }

  String getLocalizedPlaybackOrder(BuildContext context, FinampPlaybackOrder playbackOrder) {
    switch (playbackOrder) {
      case FinampPlaybackOrder.linear:
        return AppLocalizations.of(context)!.playbackOrderLinearButtonTooltip;
      case FinampPlaybackOrder.shuffled:
        return AppLocalizations.of(context)!.playbackOrderShuffledButtonTooltip;
    }
  }
}
