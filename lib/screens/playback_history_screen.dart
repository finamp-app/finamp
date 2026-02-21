import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/PlaybackHistoryScreen/playback_history_list.dart';
import 'package:finamp/components/PlaybackHistoryScreen/share_offline_listens_button.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PlaybackHistoryScreen extends StatelessWidget {
  const PlaybackHistoryScreen({super.key});

  static const routeName = "/playbackhistory";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(AppLocalizations.of(context)!.playbackHistory),
        leading: FinampAppBarBackButton(),
        actions: const [ShareOfflineListensButton()],
      ),
      body: PlaybackHistoryList(),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}
