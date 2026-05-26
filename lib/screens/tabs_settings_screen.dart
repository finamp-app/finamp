import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/LayoutSettingsScreen/TabsSettingsScreen/hide_tab_toggle.dart';

class TabsSettingsScreen extends ConsumerWidget {
  const TabsSettingsScreen({super.key});

  static const routeName = "/settings/tabs";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabOrder = ref.watch(finampSettingsProvider.tabOrder);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabs),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetTabsSettings),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 200.0),
        buildDefaultDragHandles: false,
        itemCount: tabOrder.length,
        itemBuilder: (context, index) {
          return HideTabToggle(tabContentType: tabOrder[index], key: ValueKey(tabOrder[index]), index: index);
        },
        onReorder: (oldIndex, newIndex) {
          // For some weird reason newIndex is one above what it should be
          // when oldIndex is lower. This if statement is in Flutter's
          // ReorderableListView documentation.
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }

          var currentTabOrder = List.of(tabOrder);

          // move all values below newIndex down by one
          final oldTab = currentTabOrder[oldIndex];
          currentTabOrder.removeAt(oldIndex);
          currentTabOrder.insert(newIndex, oldTab);
          FinampSetters.setTabOrder(currentTabOrder);
        },
      ),
    );
  }
}
