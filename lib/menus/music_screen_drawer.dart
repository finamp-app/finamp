import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/MusicScreen/offline_mode_switch_list_tile.dart';
import 'package:finamp/components/MusicScreen/view_list_tile.dart';
import 'package:finamp/screens/downloads_screen.dart';
import 'package:finamp/screens/logs_screen.dart';
import 'package:finamp/components/MusicScreen/offline_mode_status_label.dart';
import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/screens/settings_screen.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

class MusicScreenDrawer extends StatelessWidget {
  const MusicScreenDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final colorScheme = ColorScheme.of(context);
    return Drawer(
      surfaceTintColor: colorScheme.surfaceTint,
      backgroundColor: colorScheme.surface,
      child: ListTileTheme(
        // Shrink trailing padding from 24 to 8
        contentPadding: const EdgeInsetsDirectional.only(start: 16.0, end: 8.0),
        // Manually handle padding in leading/trailing icons
        horizontalTitleGap: 0,
        child: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                DrawerHeader(
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(padding: const EdgeInsets.all(16.0), child: FinampIcon(56, 56)),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter - const Alignment(0, 0.2),
                        child: Text(AppLocalizations.of(context)!.finamp, style: const TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                ),
                const OfflineModeSwitchListTile(),
                const OfflineModeStatusLabel(),
                Divider(),
                ListTile(
                  leading: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.file_download)),
                  title: Text(AppLocalizations.of(context)!.downloads),
                  onTap: () => Navigator.of(context).pushNamed(DownloadsScreen.routeName),
                ),
                ListTile(
                  leading: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(TablerIcons.clock)),
                  title: Text(AppLocalizations.of(context)!.playbackHistory),
                  onTap: () => Navigator.of(context).pushNamed(PlaybackHistoryScreen.routeName),
                ),
                ListTile(
                  leading: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.auto_delete)),
                  title: Text(AppLocalizations.of(context)!.queuesScreen),
                  onTap: () => Navigator.of(context).pushNamed(QueueRestoreScreen.routeName),
                ),
                const Divider(),
              ]),
            ),
            // This causes an error when logging out if we show this widget
            if (finampUserHelper.currentUser != null)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return ViewListTile(view: finampUserHelper.currentUser!.views.values.elementAt(index));
                }, childCount: finampUserHelper.currentUser!.views.length),
              ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                bottom: true,
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(),
                      ListTile(
                        leading: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.warning)),
                        title: Text(AppLocalizations.of(context)!.logs),
                        onTap: () => Navigator.of(context).pushNamed(LogsScreen.routeName),
                      ),
                      ListTile(
                        leading: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.settings)),
                        title: Text(AppLocalizations.of(context)!.settings),
                        onTap: () => Navigator.of(context).pushNamed(SettingsScreen.routeName),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
