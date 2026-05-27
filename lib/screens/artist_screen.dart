import 'package:finamp/components/ArtistScreen/artist_screen_content.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, this.widgetArtist, this.genreFilter});

  static const routeName = "/music/artist";

  /// The artist to show. Can also be provided as an argument in a named route
  final BaseItemDto? widgetArtist;

  // The genreFilter to apply
  final BaseItemDto? genreFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BaseItemDto artist = widgetArtist ?? ModalRoute.settingsOf(context)!.arguments as BaseItemDto;
    final finampUserHelper = GetIt.instance<FinampUserHelper>();

    return Scaffold(
      extendBody: true,
      body: ArtistScreenContent(
        parent: artist,
        library: finampUserHelper.currentUser?.currentView,
        genreFilter: genreFilter,
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}
