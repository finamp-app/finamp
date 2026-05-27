import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';
import '../../menus/choice_menu.dart';
import '../../models/finamp_models.dart';
import '../../models/jellyfin_models.dart';
import '../../screens/home_screen_settings_screen.dart';
import '../../services/feedback_helper.dart';
import '../../services/finamp_settings_helper.dart';
import '../Buttons/cta_medium.dart';
import '../themed_bottom_sheet.dart';

const quickActionPickerMenuRouteName = "/quick-action-preset-picker-menu";

Future<void> editQuickAction(BuildContext context, int index) async {
  if (!context.mounted) return;
  final quickActions = FinampSettingsHelper.finampSettings.homeScreenConfiguration.actions;
  final selectedAction = await showQuickActionPresetPickerMenu(context, quickActions[index]);
  if (selectedAction != null) {
    final newHomeScreenConfig = FinampSettingsHelper.finampSettings.homeScreenConfiguration.copyWith(
      actions: [...quickActions]..[index] = selectedAction,
    );
    FinampSetters.setHomeScreenConfiguration(newHomeScreenConfig);
  }
}

Future<QuickActionConfig?> showQuickActionPresetPickerMenu(BuildContext context, QuickActionConfig? initialValue) {
  return showThemedBottomSheet<QuickActionConfig?>(
    context: context,
    routeName: quickActionPickerMenuRouteName,
    minDraggableHeight: 0.25,
    buildWrapper: (context, _, buildChildren) {
      return QuickActionConfigMenu(buildChildren: buildChildren, initialValue: initialValue);
    },
  );
}

class QuickActionConfigMenu extends ConsumerStatefulWidget {
  final ScrollBuilder buildChildren;
  final QuickActionConfig? initialValue;

  const QuickActionConfigMenu({super.key, required this.buildChildren, this.initialValue});

  @override
  QuickActionConfigMenuState createState() => QuickActionConfigMenuState();
}

class QuickActionConfigMenuState extends ConsumerState<QuickActionConfigMenu> {
  FinampQuickActions? selected;
  final ValueNotifier<BaseItemDto?> notifier = ValueNotifier(null);

  @override
  void initState() {
    if (widget.initialValue?.action.editable ?? false) {
      selected = widget.initialValue?.action;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> menuItems;
    final double stackHeight;
    if (selected == null) {
      menuItems = _buildSelector();
      // header + menu entries
      stackHeight = 42.0 + menuItems.length * ((Platform.isAndroid || Platform.isIOS) ? 72.0 : 64.0);
    } else {
      final searchHeight = MediaQuery.sizeOf(context).height * 0.5;
      menuItems = _buildItemSelector(height: searchHeight);
      // header + menu entries
      stackHeight = 42.0 + searchHeight;
    }

    final menu = [
      SliverStickyHeader(
        header: Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2.0,
            children: [
              Text(switch (selected) {
                FinampQuickActions.playSpecificItem => context.l10n.selectAnItem,
                _ => context.l10n.homeScreenQuickActionPickerMenuTitle,
              }, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        sliver: MenuMask(
          height: MenuMaskHeight(36.0),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList.list(children: menuItems),
          ),
        ),
      ),
    ];
    return widget.buildChildren(stackHeight, menu);
  }

  List<Widget> _buildSelector() {
    return FinampQuickActions.values.map<Widget>((quickAction) {
      return Consumer(
        builder: (context, ref, child) {
          return ChoiceMenuOption(
            title: QuickActionConfig(action: quickAction).getTitle(context.l10n),
            description: quickAction.getDescription(context),
            badges: [
              // // similar mode is recommended
              // if (preset == RadioMode.similar && radioModeOptionAvailabilityStatus.isAvailable)
              //   Icon(TablerIcons.star, size: 14.0),
            ],
            enabled: true,
            icon: quickAction.getIcon(),
            isInactive: false,
            isSelected: quickAction == widget.initialValue?.action,
            onSelect: () async {
              //TODO ideally rebuild with check and then pop after delay
              // FeedbackHelper.feedback(FeedbackType.selection);
              // await Future<void>.delayed(const Duration(milliseconds: 400));
              // Navigator.of(context).pop(preset);
              if (quickAction.editable) {
                setState(() {
                  selected = quickAction;
                });
              } else {
                if (context.mounted) {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  Navigator.of(context).pop(QuickActionConfig(action: quickAction));
                }
              }
            },
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildItemSelector({required double height}) {
    // This is currently the only editable type
    assert(selected == FinampQuickActions.playSpecificItem);
    return [
      ChoiceMenuOption(
        title: context.l10n.back,
        enabled: true,
        icon: TablerIcons.chevron_left,
        isInactive: false,
        isSelected: false,
        onSelect: () => setState(() {
          selected = null;
        }),
      ),
      GlobalSearchBox(notifier, height: height, initialItem: widget.initialValue?.itemId, showTracks: true),
      SizedBox(height: 20.0),
      ValueListenableBuilder(
        valueListenable: notifier,
        builder: (context, value, _) {
          return CTAMedium(
            text: context.l10n.save,
            icon: TablerIcons.device_floppy,
            disabled: value == null,
            onPressed: () {
              if (context.mounted && value != null) {
                FeedbackHelper.feedback(FeedbackType.selection);
                Navigator.of(context).pop(
                  QuickActionConfig(
                    action: FinampQuickActions.playSpecificItem,
                    itemId: value.id,
                    itemName: value.name,
                  ),
                );
              }
            },
          );
        },
      ),
    ];
  }
}
