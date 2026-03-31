import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../components/LayoutSettingsScreen/TabsSettingsScreen/hide_tab_toggle.dart';

class TabsSettingsScreen extends StatefulWidget {
  const TabsSettingsScreen({super.key});

  static const routeName = "/settings/tabs";

  @override
  State<TabsSettingsScreen> createState() => _TabsSettingsScreenState();
}

class _TabsSettingsScreenState extends State<TabsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final musicTabOrder = FinampSettingsHelper.finampSettings.tabOrder;
    final bookTabOrder = FinampSettingsHelper.finampSettings.bookTabOrder;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tabs),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
              context, FinampSettingsHelper.resetTabsSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.musicTabsLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: musicTabOrder.length,
            itemBuilder: (context, index) {
              return HideTabToggle(
                tabContentType: musicTabOrder[index],
                key: ValueKey(musicTabOrder[index]),
                index: index,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                var current = List.of(musicTabOrder);
                final item = current.removeAt(oldIndex);
                current.insert(newIndex, item);
                FinampSetters.setTabOrder(current);
              });
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.booksTabsLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: bookTabOrder.length,
            itemBuilder: (context, index) {
              return HideTabToggle(
                tabContentType: bookTabOrder[index],
                key: ValueKey(bookTabOrder[index]),
                index: index,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                var current = List.of(bookTabOrder);
                final item = current.removeAt(oldIndex);
                current.insert(newIndex, item);
                FinampSetters.setBookTabOrder(current);
              });
            },
          ),
        ],
      ),
    );
  }
}
