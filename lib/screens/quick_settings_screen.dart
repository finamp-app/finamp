import 'package:finamp/screens/network_settings_screen.dart';
import 'package:finamp/screens/settings_screen.dart';
import 'package:finamp/screens/tabs_settings_screen.dart';
import 'package:finamp/screens/transcoding_settings_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../components/AlbumScreen/download_button.dart';
import '../components/LayoutSettingsScreen/automatic_accent_color_selector.dart';
import '../components/LayoutSettingsScreen/show_text_on_grid_view_selector.dart';
import '../components/LayoutSettingsScreen/theme_selector.dart';
import '../components/NetworkSettingsScreen/auto_offline_selector.dart';
import '../components/TranscodingSettingsScreen/bitrate_selector.dart';
import '../components/TranscodingSettingsScreen/transcode_switch.dart';
import '../components/finamp_app_bar_back_button.dart';
import '../extensions/localizations.dart';
import '../l10n/app_localizations.dart';
import '../models/finamp_models.dart';
import '../services/finamp_user_helper.dart';
import 'accessibility_settings_screen.dart';
import 'content_view_type_settings_screen.dart';
import 'layout_settings_screen.dart';

class QuickSettingsScreen extends ConsumerWidget {
  const QuickSettingsScreen({super.key});

  static const routeName = "/settings/quick-settings";

  static const fromSettingsScreen = Object();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.quickSettingsScreen), leading: FinampAppBarBackButton()),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(style: TextTheme.of(context).bodyLarge, context.l10n.quickSettingsScreenDescription),
          ),
          if (ModalRoute.settingsOf(context)!.arguments != fromSettingsScreen)
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(context.l10n.quickSettingsAllSettingsLink),
              onTap: () => Navigator.of(context).pushNamed(SettingsScreen.routeName),
            ),
          ListTile(
            leading: const Icon(TablerIcons.accessible),
            title: Text(AppLocalizations.of(context)!.accessibility),
            onTap: () => Navigator.of(context).pushNamed(AccessibilitySettingsScreen.routeName),
          ),
          Divider(),
          // music screen tabs
          ListTile(
            leading: const Icon(Icons.tab),
            title: Text(context.l10n.quickSettingsTabsLink),
            onTap: () => Navigator.of(context).pushNamed(TabsSettingsScreen.routeName),
          ),
          const SizedBox(height: 8.0),
          // dark mode
          const ThemeSelector(verbose: true),
          const SizedBox(height: 8.0),
          const AutomaticAccentColorSelector(),
          const SizedBox(height: 8.0),
          // grid mode toggle plus size
          const ContentViewTypeDropdownListTile(),
          if (watchDropdownContentViewType(ref) == DropdownContentViewType.custom)
            ListTile(
              leading: const Icon(TablerIcons.layout),
              title: Text(context.l10n.perTabGridModeScreen),
              onTap: () => Navigator.of(context).pushNamed(ContentViewTypeSettingsScreen.routeName),
              contentPadding: EdgeInsets.only(left: 50),
            ),
          if (watchDropdownContentViewType(ref) != DropdownContentViewType.list) const ShowTextOnGridViewSelector(),
          if (watchDropdownContentViewType(ref) != DropdownContentViewType.list) const GridImageSizeSelector(),
          ListTile(
            leading: const Icon(Icons.widgets),
            title: Text(context.l10n.quickSettingsLayoutLink),
            onTap: () => Navigator.of(context).pushNamed(LayoutSettingsScreen.routeName),
            trailing: const Icon(TablerIcons.chevron_right),
          ),
          Divider(),
          // auto-offline mode?
          AutoOfflineSelector(),
          ListTile(
            leading: const Icon(TablerIcons.wifi),
            title: Text(context.l10n.quickSettingsNetworkLink),
            onTap: () => Navigator.of(context).pushNamed(NetworkSettingsScreen.routeName),
            trailing: const Icon(TablerIcons.chevron_right),
          ),
          Divider(),
          // transcode + deeper link
          const TranscodeSwitch(),
          if (ref.watch(finampSettingsProvider.shouldTranscode)) const BitrateSelector(),
          ListTile(
            leading: const Icon(Icons.compress),
            title: Text(context.l10n.quickSettingsTranscodeLink),
            onTap: () => Navigator.of(context).pushNamed(TranscodingSettingsScreen.routeName),
            trailing: const Icon(TablerIcons.chevron_right),
          ),
          Divider(),
          // album image cache?
          ListTile(
            title: Text(AppLocalizations.of(context)!.cacheLibraryImagesSettings),
            subtitle: Text(AppLocalizations.of(context)!.cacheLibraryImagesSettingsSubtitle),
            trailing: DownloadButton(
              item: DownloadStub.fromFinampCollection(
                FinampCollection(
                  type: FinampCollectionType.libraryImages,
                  library: GetIt.instance<FinampUserHelper>().currentUser!.currentView!,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
