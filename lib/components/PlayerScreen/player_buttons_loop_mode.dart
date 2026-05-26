import 'package:finamp/components/Shortcuts/global_shortcut_manager.dart';
import 'package:finamp/components/Shortcuts/music_control_shortcuts.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/radio_mode_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:finamp/utils/locale_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class PlayerButtonsLoopMode extends ConsumerWidget {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  final queueService = GetIt.instance<QueueService>();

  PlayerButtonsLoopMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    final radioMode = ref.watch(finampSettingsProvider.radioMode);
    final radioEnabled = ref.watch(finampSettingsProvider.radioEnabled);
    final currentRadioAvailabilityStatus = ref.watch(currentRadioAvailabilityStatusProvider);
    final radioFailed = ref.watch(radioStateProvider.select((state) => state?.failed ?? false));

    IconData getRepeatingIcon(FinampLoopMode loopMode) {
      if (radioEnabled) {
        return (currentRadioAvailabilityStatus.isAvailable && !radioFailed) ? TablerIcons.radio : TablerIcons.radio_off;
      }
      if (loopMode == FinampLoopMode.all) {
        return TablerIcons.repeat;
      } else if (loopMode == FinampLoopMode.one) {
        return TablerIcons.repeat_once;
      } else {
        return TablerIcons.repeat_off;
      }
    }

    String getLocalizedLoopMode(BuildContext context, FinampLoopMode loopMode) {
      if (radioEnabled) {
        if (radioFailed) {
          return AppLocalizations.of(context)!.radioFailedSubtitle;
        }
        return currentRadioAvailabilityStatus.isAvailable
            ? AppLocalizations.of(context)!.radioModeOptionTitle(radioMode.name)
            : AppLocalizations.of(context)!.radioModeInactiveTitle;
      }
      switch (loopMode) {
        case FinampLoopMode.all:
          return AppLocalizations.of(context)!.loopModeAllButtonLabel;
        case FinampLoopMode.one:
          return AppLocalizations.of(context)!.loopModeOneButtonLabel;
        case FinampLoopMode.none:
          return AppLocalizations.of(context)!.loopModeNoneButtonLabel;
      }
    }

    return StreamBuilder(
      stream: queueService.getLoopModeStream(),
      initialData: queueService.loopMode,
      builder: (BuildContext context, snapshot) {
        final shortcutHint = GlobalShortcuts.getDisplay(ToggleLoopModeIntent);
        final loopModeHint = getLocalizedLoopMode(context, snapshot.data!);
        return IconButton(
          tooltip: getStringComponentsInLocaleOrder(context, [
            loopModeHint,
            AppLocalizations.of(context)!.genericToggleButtonTooltip,
            "($shortcutHint)",
          ], separator: "\n"),
          onPressed: () async {
            if (radioEnabled) {
              await showRadioMenu(
                context,
                subtitle: radioFailed ? AppLocalizations.of(context)!.radioFailedSubtitle : null,
              );
            } else {
              FeedbackHelper.feedback(FeedbackType.light);
              queueService.toggleLoopMode();
            }
          },
          onLongPress: () => showRadioMenu(
            context,
            subtitle: radioFailed
                ? AppLocalizations.of(context)!.radioFailedSubtitle
                : AppLocalizations.of(context)!.loopingOverriddenByRadioSubtitle,
          ),
          icon: Icon(getRepeatingIcon(snapshot.data!)),
        );
      },
    );
  }
}
