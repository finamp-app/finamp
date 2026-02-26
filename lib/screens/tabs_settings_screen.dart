import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/LayoutSettingsScreen/TabsSettingsScreen/hide_tab_toggle.dart';

class TabsSettingsScreen extends ConsumerStatefulWidget {
  const TabsSettingsScreen({super.key});

  static const routeName = "/settings/tabs";

  @override
  ConsumerState<TabsSettingsScreen> createState() => _TabsSettingsScreenState();
}

class _TabsSettingsScreenState extends ConsumerState<TabsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabs),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(context, FinampSettingsHelper.resetTabsSettings),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 200.0),
        buildDefaultDragHandles: false,
        itemCount: ref.watch(finampSettingsProvider.tabOrder).length,
        itemBuilder: (context, index) {
          return HideTabToggle(
            tabContentType: ref.watch(finampSettingsProvider.tabOrder)[index],
            key: ValueKey(ref.watch(finampSettingsProvider.tabOrder)[index]),
            index: index,
          );
        },
        onReorder: (oldIndex, newIndex) {
          // It's a bit of a hack to call setState with no actual widget
          // state, but it saves us from using listeners
          setState(() {
            // For some weird reason newIndex is one above what it should be
            // when oldIndex is lower. This if statement is in Flutter's
            // ReorderableListView documentation.
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }

            var currentTabOrder = List.of(FinampSettingsHelper.finampSettings.tabOrder);

            // move all values below newIndex down by one
            final oldTab = currentTabOrder[oldIndex];
            currentTabOrder.removeAt(oldIndex);
            currentTabOrder.insert(newIndex, oldTab);
            FinampSetters.setTabOrder(currentTabOrder);
          });
        },
      ),
    );
  }
}
