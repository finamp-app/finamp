import 'dart:io';
import 'dart:math';

import 'package:finamp/components/HomeScreen/finamp_music_screen_header.dart';
import 'package:finamp/components/MusicScreen/offline_mode_status_label.dart';
import 'package:finamp/components/MusicScreen/offline_mode_switch_list_tile.dart';
import 'package:finamp/components/MusicScreen/view_list_tile.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/downloads_screen.dart';
import 'package:finamp/screens/logs_screen.dart';
import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/screens/settings_screen.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/server_info_provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../extensions/localizations.dart';

class MusicScreenDrawer extends ConsumerWidget {
  const MusicScreenDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final downloadsService = GetIt.instance<DownloadsService>();
    final colorScheme = ColorScheme.of(context);
    final FinampSettings? settings = ref.watch(finampSettingsProvider).value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = min(304.0, constraints.maxWidth * .70);
        final excessWidth = constraints.maxWidth - minWidth;
        final expandedWidth = minWidth + excessWidth * 0.5;
        final targetWidth = min(expandedWidth, 450.0);
        return Drawer(
          surfaceTintColor: colorScheme.surfaceTint,
          backgroundColor: colorScheme.surface,
          width: targetWidth,
          child: SafeArea(
            bottom: false,
            child: ListTileTheme(
              // Shrink trailing padding from 24 to 8
              contentPadding: const EdgeInsetsDirectional.only(start: 16.0, end: 8.0),
              // Manually handle padding in leading/trailing icons
              horizontalTitleGap: 0,
              child: CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      Padding(
                        padding: EdgeInsetsGeometry.only(left: 16, right: 16, top: 12, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 12),
                            FinampIcon(
                              56,
                              56,
                              overrideColor: ref.watch(finampSettingsProvider.isOffline)
                                  ? TextTheme.of(context).bodyMedium?.color?.withOpacity(0.6)
                                  : null,
                            ),
                            SizedBox(height: 8),
                            Text(
                              ref.watch(packageNameProvider).valueOrNull ?? AppLocalizations.of(context)!.finamp,
                              style: const TextStyle(fontSize: 20),
                            ),
                            if (settings?.isOffline ?? false)
                              Text.rich(
                                TextSpan(
                                  text: AppLocalizations.of(context)!.offlineMode,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Text.rich(
                                TextSpan(
                                  text: context.l10n.connectedTo,
                                  children: [
                                    TextSpan(
                                      text:
                                          " ${ref.watch(currentServerInfoProvider).value?.publicServerInfo.serverName ?? context.l10n.unknown}",
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    if (ref.watch(currentServerInfoProvider).value?.publicServerInfo.version != null)
                                      TextSpan(
                                        text:
                                            " (v${ref.watch(currentServerInfoProvider).value?.publicServerInfo.version})",
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (ref.watch(isDownloadingOrSyncingPollingProvider)) ...[
                              SizedBox(height: 8),
                              Text(
                                context.l10n.connectionStateInfoString(
                                  ((ref.watch(FinampUserHelper.finampCurrentUserProvider)?.isLocal ?? false)
                                          ? switch (true) {
                                              _ when downloadsService.syncBuffer.isRunning =>
                                                ConnectionStateInfo.syncingLocal,
                                              _ when downloadsService.downloadTaskQueue.isRunning =>
                                                ConnectionStateInfo.downloadingLocal,
                                              _ when downloadsService.deleteBuffer.isRunning =>
                                                ConnectionStateInfo.deleting,
                                              _ => ConnectionStateInfo.connectedLocal,
                                            }
                                          : switch (true) {
                                              _ when downloadsService.syncBuffer.isRunning =>
                                                ConnectionStateInfo.syncing,
                                              _ when downloadsService.downloadTaskQueue.isRunning =>
                                                ConnectionStateInfo.downloading,
                                              _ when downloadsService.deleteBuffer.isRunning =>
                                                ConnectionStateInfo.deleting,
                                              _ => ConnectionStateInfo.other,
                                            })
                                      .name,
                                ),
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const OfflineModeSwitchListTile(),
                      const OfflineModeStatusLabel(),
                      ListTile(
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 2.0, right: 12.0),
                          child: Icon(Icons.file_download, size: 20.0),
                        ),
                        title: Text(AppLocalizations.of(context)!.downloads, style: TextStyle(fontSize: 15.0)),
                        onTap: () => Navigator.of(context).pushNamed(DownloadsScreen.routeName),
                        dense: true,
                      ),
                      ListTile(
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 2.0, right: 12.0),
                          child: Icon(TablerIcons.clock, size: 20.0),
                        ),
                        title: Text(AppLocalizations.of(context)!.playbackHistory, style: TextStyle(fontSize: 15.0)),
                        onTap: () => Navigator.of(context).pushNamed(PlaybackHistoryScreen.routeName),
                        dense: true,
                      ),
                      ListTile(
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 2.0, right: 12.0),
                          child: Icon(Icons.auto_delete, size: 20.0),
                        ),
                        title: Text(AppLocalizations.of(context)!.queuesScreen, style: TextStyle(fontSize: 15.0)),
                        onTap: () => Navigator.of(context).pushNamed(QueueRestoreScreen.routeName),
                        dense: true,
                      ),
                    ]),
                  ),
                  // This causes an error when logging out if we show this widget
                  if (finampUserHelper.currentUser != null) ...[
                    SliverPadding(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 12.0, bottom: 4.0),
                      sliver: SliverToBoxAdapter(
                        child: Text.rich(
                          TextSpan(
                            text: AppLocalizations.of(context)!.activeLibraries,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
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
                              leading: const Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(Icons.warning, size: 20.0),
                              ),
                              title: Text(AppLocalizations.of(context)!.logs, style: TextStyle(fontSize: 15.0)),
                              onTap: () => Navigator.of(context).pushNamed(LogsScreen.routeName),
                              dense: true,
                            ),
                            ListTile(
                              leading: const Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(Icons.settings, size: 20.0),
                              ),
                              title: Text(AppLocalizations.of(context)!.settings, style: TextStyle(fontSize: 15.0)),
                              onTap: () => Navigator.of(context).pushNamed(SettingsScreen.routeName),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final packageNameProvider = FutureProvider((Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  if (Platform.isLinux) {
    return info.appName.capitalize;
  }
  return info.appName;
});

enum ConnectionStateInfo { syncing, downloading, deleting, connectedLocal, syncingLocal, downloadingLocal, other }
