import 'package:finamp/components/SettingsScreen/finamp_settings_dropdown.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';
import '../../models/finamp_models.dart';
import '../../services/finamp_settings_helper.dart';

class ContentViewTypeDropdownListTile extends ConsumerWidget {
  const ContentViewTypeDropdownListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.viewType),
      subtitle: Column(
        spacing: 4.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.viewTypeSubtitle),
          FinampSettingsDropdown<ContentViewType>(
            dropdownItems: ContentViewType.values
                .map(
                  (e) => DropdownMenuEntry<ContentViewType>(
                    value: e,
                    label: e.toLocalisedString(context.l10n),
                    leadingIcon: switch (e) {
                      ContentViewType.list => const Icon(TablerIcons.layout_list),
                      ContentViewType.grid => const Icon(TablerIcons.layout_grid),
                    },
                  ),
                )
                .toList(),
            selectedValue: ref.watch(finampSettingsProvider.contentViewType),
            onSelected: (value) {
              if (value != null) {
                FinampSetters.setContentViewType(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
