import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../components/HomeScreen/home_section_editor.dart';
import '../../../extensions/localizations.dart';
import 'menu_entry.dart';

class EditHomeSectionMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final HomeScreenSectionConfiguration section;

  const EditHomeSectionMenuEntry({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSections = ref.watch(finampSettingsProvider.homeScreenConfiguration.select((x) => x.sections));

    final activeIndex = activeSections.indexWhere((x) {
      // find the index of the section which is exactly identical, including name.
      return x == section && x.presetType == section.presetType && x.customSectionTitle == section.customSectionTitle;
    });

    return Visibility(
      visible: activeIndex >= 0,
      child: MenuEntry(
        icon: TablerIcons.edit,
        title: context.l10n.editSection,
        onTap: () {
          if (context.mounted) {
            Navigator.of(context).pop();
            editHomeScreenSection(context, activeIndex);
          }
        },
      ),
    );
  }

  @override
  bool get isVisible => true;
}
