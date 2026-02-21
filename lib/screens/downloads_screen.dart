import 'package:flutter/material.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/DownloadsScreen/download_error_screen_button.dart';
import 'package:finamp/components/DownloadsScreen/downloaded_items_list.dart';
import 'package:finamp/components/DownloadsScreen/downloads_overview.dart';
import 'package:finamp/components/DownloadsScreen/repair_downloads_button.dart';
import 'package:finamp/components/DownloadsScreen/sync_downloads_button.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/padded_custom_scrollview.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  static const routeName = "/downloads";

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.downloads),
        leading: FinampAppBarBackButton(),
        actions: const [SyncDownloadsButton(), RepairDownloadsButton(), DownloadErrorScreenButton()],
      ),
      body: PaddedCustomScrollview(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              const Padding(
                // We don't have bottom padding here since the divider already provides bottom padding
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: DownloadsOverview(),
              ),
              const Divider(),
            ]),
          ),
          DownloadedItemsTitle(title: localizations.specialDownloads),
          const DownloadedItemsList(type: DownloadsScreenCategory.special),
          DownloadedItemsTitle(title: localizations.libraryDownloads),
          const DownloadedItemsList(type: DownloadsScreenCategory.library),
          DownloadedItemsTitle(title: localizations.playlists),
          const DownloadedItemsList(type: DownloadsScreenCategory.playlists),
          DownloadedItemsTitle(title: localizations.artists),
          const DownloadedItemsList(type: DownloadsScreenCategory.artists),
          DownloadedItemsTitle(title: localizations.albums),
          const DownloadedItemsList(type: DownloadsScreenCategory.albums),
          DownloadedItemsTitle(title: localizations.genres),
          const DownloadedItemsList(type: DownloadsScreenCategory.genres),
          DownloadedItemsTitle(title: localizations.tracks),
          const DownloadedItemsList(type: DownloadsScreenCategory.tracks),
        ],
      ),
    );
  }
}

void showSyncWarningSnackbar() {
  GlobalSnackbar.message(
    (scaffold) => AppLocalizations.of(scaffold)!.syncFailedWarningShort,
    action: (context) => SnackBarAction(
      label: MaterialLocalizations.of(context).moreButtonTooltip,
      onPressed: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.syncFailedWarningShort),
          content: Text(AppLocalizations.of(context)!.syncFailedWarningLong),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popAndPushNamed(DownloadsScreen.routeName);
              },
              child: Text(AppLocalizations.of(context)!.openDownloads),
            ),
          ],
        ),
      ),
    ),
  );
}
