import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extensions/localizations.dart';

class ItemSwipeLeftToRightActionDropdownListTile extends ConsumerWidget {
  const ItemSwipeLeftToRightActionDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var action = ref.watch(finampSettingsProvider.itemSwipeActionLeftToRight);
    return ListTile(
      title: Text(AppLocalizations.of(context)!.swipeLeftToRightAction),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.swipeLeftToRightActionSubtitle),
          FinampSettingsDropdown<ItemSwipeActions>(
            dropdownItems: ItemSwipeActions.values
                .map((e) => DropdownMenuEntry<ItemSwipeActions>(value: e, label: e.toLocalisedString(context.l10n)))
                .toList(),
            selectedValue: action,
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setItemSwipeActionLeftToRight(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class ItemSwipeRightToLeftActionDropdownListTile extends ConsumerWidget {
  const ItemSwipeRightToLeftActionDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var action = ref.watch(finampSettingsProvider.itemSwipeActionRightToLeft);
    return ListTile(
      title: Text(AppLocalizations.of(context)!.swipeRightToLeftAction),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.swipeRightToLeftActionSubtitle),
          FinampSettingsDropdown<ItemSwipeActions>(
            dropdownItems: ItemSwipeActions.values
                .map((e) => DropdownMenuEntry<ItemSwipeActions>(value: e, label: e.toLocalisedString(context.l10n)))
                .toList(),
            selectedValue: action,
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setItemSwipeActionRightToLeft(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
