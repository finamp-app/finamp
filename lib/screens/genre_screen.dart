import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/genre_screen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../components/GenreScreen/genre_screen_content.dart';
import '../components/now_playing_bar.dart';
import '../models/jellyfin_models.dart';

class GenreScreen extends ConsumerStatefulWidget {
  const GenreScreen({super.key, this.widgetGenre});

  static const routeName = "/music/genre";

  /// The genre to show. Can also be provided as an argument in a named route
  final BaseItemDto? widgetGenre;

  @override
  ConsumerState<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends ConsumerState<GenreScreen> {
  final _finampUserHelper = GetIt.instance<FinampUserHelper>();
  Key _contentKey = UniqueKey();

  Future<void> _refresh() async {
    ref.invalidate(genreCuratedItemsProvider);
    setState(() {
      _contentKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final BaseItemDto genre = widget.widgetGenre ?? ModalRoute.settingsOf(context)!.arguments as BaseItemDto;

    return Scaffold(
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: GenreScreenContent(key: _contentKey, parent: genre, library: _finampUserHelper.currentUser?.currentView),
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}
