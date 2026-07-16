import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../models/jellyfin_models.dart';
import '../models/finamp_models.dart';
import '../services/jellyfin_api_helper.dart';
import '../services/finamp_settings_helper.dart';
import '../services/downloads_helper.dart';
import '../components/now_playing_bar.dart';
import '../components/selection_action_bar.dart';
import '../components/song_selection_controller.dart';
import '../components/AlbumScreen/album_screen_content.dart';
import '../services/music_player_background_task.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({
    Key? key,
    this.parent,
  }) : super(key: key);

  static const routeName = "/music/album";

  /// The album to show. Can also be provided as an argument in a named route
  final BaseItemDto? parent;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  Future<List<BaseItemDto>?>? albumScreenContentFuture;
  JellyfinApiHelper jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

  @override
  Widget build(BuildContext context) {
    final BaseItemDto parent = widget.parent ??
        ModalRoute.of(context)!.settings.arguments as BaseItemDto;

    return ChangeNotifierProvider(
      create: (_) => SongSelectionController(),
      child: Scaffold(
        body: ValueListenableBuilder<Box<FinampSettings>>(
          valueListenable: FinampSettingsHelper.finampSettingsListener,
          builder: (context, box, widget) {
            bool isOffline = box.get("FinampSettings")?.isOffline ?? false;

            if (isOffline) {
              final downloadsHelper = GetIt.instance<DownloadsHelper>();

              // The downloadedParent won't be null here if we've already
              // navigated to it in offline mode
              final downloadedParent =
                  downloadsHelper.getDownloadedParent(parent.id)!;

              return AlbumScreenContent(
                parent: downloadedParent.item,
                children: downloadedParent.downloadedChildren.values.toList(),
              );
            } else {
              albumScreenContentFuture ??= jellyfinApiHelper.getItems(
                parentItem: parent,
                sortBy: "ParentIndexNumber,IndexNumber,SortName",
                includeItemTypes: "Audio",
                isGenres: false,
              );

              return FutureBuilder<List<BaseItemDto>?>(
                future: albumScreenContentFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final List<BaseItemDto> items = snapshot.data!;

                    return AlbumScreenContent(parent: parent, children: items);
                  } else if (snapshot.hasError) {
                    return CustomScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          title: Text(AppLocalizations.of(context)!.error),
                        ),
                        SliverFillRemaining(
                          child: Center(child: Text(snapshot.error.toString())),
                        )
                      ],
                    );
                  } else {
                    // We return all of this so that we can have an app bar while loading.
                    // This is especially important for iOS, where there isn't a hardware back button.
                    return CustomScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          title: Text(parent.name ??
                              AppLocalizations.of(context)!.unknownName),
                        ),
                        const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        )
                      ],
                    );
                  }
                },
              );
            }
          },
        ),
        bottomNavigationBar:
            const SelectionAwareBottomBar(child: NowPlayingBar()),
      ),
    );
  }
}
