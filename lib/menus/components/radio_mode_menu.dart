import 'dart:async';
import 'dart:io';

import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/choice_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

Future<void> showRadioMenu(
  BuildContext context, {
  BaseItemDto? seedItem,
  bool startNewQueue = false,
  String? subtitle,
}) async {
  final queueService = GetIt.instance<QueueService>();

  assert(startNewQueue == (seedItem != null), "A new queue must be started by (and when) overriding the seed item.");

  final List<Widget> menuItems = RadioMode.values
      .map<Widget>((radioModeOption) {
        return Consumer(
          builder: (context, ref, child) {
            final currentRadioMode = ref.watch(finampSettingsProvider.radioMode);
            final modeSeedItem = seedItem ?? ref.watch(getActiveRadioSeedProvider(radioModeOption));
            final radioModeOptionAvailabilityStatus = ref.watch(
              radioModeAvailabilityStatusProvider((radioModeOption, modeSeedItem)),
            );
            return ChoiceMenuOption(
              title: AppLocalizations.of(context)!.radioModeOptionName(radioModeOption.name),
              description: switch (radioModeOptionAvailabilityStatus) {
                RadioModeAvailabilityStatus.available || RadioModeAvailabilityStatus.disabled => AppLocalizations.of(
                  context,
                )!.radioModeDescription(radioModeOption.name),
                RadioModeAvailabilityStatus.unavailableSourceTypeNotSupported ||
                RadioModeAvailabilityStatus.unavailableSourceNull => AppLocalizations.of(
                  context,
                )!.radioModeUnavailableForSourceItemDescription,
                RadioModeAvailabilityStatus.unavailableOffline => AppLocalizations.of(
                  context,
                )!.radioModeUnavailableWhileOfflineDescription,
                RadioModeAvailabilityStatus.unavailableNotDownloaded =>
                  modeSeedItem?.name != null
                      ? AppLocalizations.of(
                          context,
                        )!.radioModeRandomUnavailableNotDownloadedDescription(modeSeedItem!.name!)
                      : AppLocalizations.of(context)!.radioModeRandomUnavailableNotDownloadedGenericDescription,
                RadioModeAvailabilityStatus.unavailableQueueEmpty => AppLocalizations.of(
                  context,
                )!.radioModeUnavailableQueueEmptyDescription,
              },
              badges: [
                // similar mode is recommended
                if (radioModeOption == RadioMode.similar && radioModeOptionAvailabilityStatus.isAvailable)
                  Icon(TablerIcons.star, size: 14.0),
              ],
              enabled: radioModeOptionAvailabilityStatus.isAvailable,
              icon: getRadioModeIcon(radioModeOption),
              isInactive:
                  startNewQueue ||
                  ref.watch(currentRadioAvailabilityStatusProvider) != RadioModeAvailabilityStatus.available,
              isSelected: currentRadioMode == radioModeOption,
              onSelect: () async {
                final radioTracksWillChange = currentRadioMode != radioModeOption || startNewQueue;
                FeedbackHelper.feedback(FeedbackType.selection);
                if (currentRadioMode != radioModeOption) {
                  FinampSetters.setRadioMode(radioModeOption);
                }
                if (seedItem != null && startNewQueue) {
                  unawaited(startRadioPlayback(seedItem));
                } else {
                  // clear tracks after updating mode to ensure any later request for radio tracks use the correct settings
                  if (radioTracksWillChange) {
                    await queueService.clearRadioTracks();
                  }
                  toggleRadio(true);
                }
                if (radioTracksWillChange) {
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        );
      })
      .followedBy(
        startNewQueue
            ? []
            : <Widget>[
                Divider(height: 8.0, thickness: 1.5, indent: 20.0, endIndent: 20.0, radius: BorderRadius.circular(2.0)),
                Consumer(
                  builder: (context, ref, child) {
                    return ChoiceMenuOption(
                      title: AppLocalizations.of(context)!.radioModeDisableButtonTitle,
                      description: AppLocalizations.of(context)!.radioModeDisableButtonSubtitle,
                      icon: TablerIcons.radio_off,
                      isSelected: !ref.watch(currentRadioAvailabilityStatusProvider).isAvailable,
                      enabled: true,
                      onSelect: () async {
                        toggleRadio(false);
                        FeedbackHelper.feedback(FeedbackType.selection);
                        await Future<void>.delayed(const Duration(milliseconds: 400));
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ],
      )
      .toList();

  await showThemedBottomSheet(
    context: context,
    item: seedItem ?? queueService.getCurrentTrack()?.baseItem,
    routeName: "/radio-menu",
    minDraggableHeight: 0.25,
    buildSlivers: (context) {
      var menu = [
        SliverStickyHeader(
          header: Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.0,
              children: [
                Text(AppLocalizations.of(context)!.radioModeMenuTitle, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          sliver: MenuMask(
            height: MenuMaskHeight(36.0),
            child: SliverList.list(children: menuItems),
          ),
        ),
      ];
      // header + menu entries
      var stackHeight = 42.0 + menuItems.length * ((Platform.isAndroid || Platform.isIOS) ? 72.0 : 64.0);
      return (stackHeight, menu);
    },
  );
}
