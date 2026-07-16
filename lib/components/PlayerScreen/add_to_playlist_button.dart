import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';
import '../../services/music_player_background_task.dart';
import '../../screens/add_to_playlist_screen.dart';

class AddToPlaylistButton extends StatelessWidget {
  const AddToPlaylistButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return IconButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(
                AddToPlaylistScreen.routeName,
                arguments: [
                  BaseItemDto.fromJson(snapshot.data!.extras!["itemJson"]).id
                ]),
            icon: const Icon(Icons.playlist_add),
            tooltip: AppLocalizations.of(context)!.addToPlaylistTooltip,
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: null,
            tooltip: AppLocalizations.of(context)!.addToPlaylistTooltip,
          );
        }
      },
    );
  }
}
