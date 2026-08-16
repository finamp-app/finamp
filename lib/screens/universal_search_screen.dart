import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../components/AlbumScreen/track_list_tile.dart';
import '../components/MusicScreen/item_wrapper.dart';
import '../extensions/localizations.dart';
import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import '../models/music_models.dart';
import '../services/finamp_settings_helper.dart';
import '../services/jellyfin_api_helper.dart';

/// A global search screen that queries the Jellyfin server across tracks,
/// albums, artists, playlists and genres, replacing the old in-tab search.
class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key});

  static const routeName = "/search";

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final _searchController = TextEditingController();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  Timer? _debounce;
  Future<List<BaseItemDto>>? _searchFuture;
  String _query = "";

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _searchFuture = _query.isEmpty ? null : _performSearch(_query);
      });
    });
  }

  Future<List<BaseItemDto>> _performSearch(String query) async {
    // A plain search term only matches item names, so searching an artist's
    // name won't surface their albums/tracks (whose titles don't contain the
    // name). We run the name search, then expand any matched artists into their
    // discography so e.g. "john williams" also lists his albums and tracks.
    final nameMatches = await _jellyfinApiHelper.getItems(
          includeItemTypes: "Audio,MusicAlbum,MusicArtist,Playlist,MusicGenre",
          searchTerm: query,
          sortBy: "SortName",
          sortOrder: "Ascending",
          startIndex: 0,
          limit: 100,
        ) ??
        [];

    final artists = nameMatches
        .where((i) => BaseItemDtoType.fromItem(i) == BaseItemDtoType.artist)
        .toList();

    // Fetch each matched artist's albums and tracks. These must be separate
    // requests: with a recursive query, a combined "MusicAlbum,Audio" fetch
    // orders the handful of albums behind hundreds of tracks, so albums can
    // fall outside the limit and never appear.
    final discographies = await Future.wait(
      artists.expand((artist) => [
            _jellyfinApiHelper.getItems(
                  parentItem: artist,
                  artistType: ArtistType.albumArtist,
                  includeItemTypes: "MusicAlbum",
                  sortBy: "SortName",
                  sortOrder: "Ascending",
                  limit: 200,
                ).then((r) => r ?? <BaseItemDto>[]),
            _jellyfinApiHelper.getItems(
                  parentItem: artist,
                  artistType: ArtistType.albumArtist,
                  includeItemTypes: "Audio",
                  sortBy: "SortName",
                  sortOrder: "Ascending",
                  limit: 200,
                ).then((r) => r ?? <BaseItemDto>[]),
          ]),
    );

    // Merge everything, de-duplicating by id, then order by type so artists and
    // albums surface above the long tail of tracks.
    final byId = <String, BaseItemDto>{};
    for (final item in [nameMatches, ...discographies].expand((l) => l)) {
      final id = item.id.raw;
      byId.putIfAbsent(id, () => item);
    }

    const typeRank = {
      BaseItemDtoType.artist: 0,
      BaseItemDtoType.album: 1,
      BaseItemDtoType.playlist: 2,
      BaseItemDtoType.genre: 3,
      BaseItemDtoType.track: 4,
    };
    final merged = byId.values.toList()
      ..sort((a, b) {
        final ra = typeRank[BaseItemDtoType.fromItem(a)] ?? 5;
        final rb = typeRank[BaseItemDtoType.fromItem(b)] ?? 5;
        if (ra != rb) return ra.compareTo(rb);
        return (a.name ?? "").toLowerCase().compareTo((b.name ?? "").toLowerCase());
      });

    return merged;
  }

  Widget _buildResultItem(List<BaseItemDto> results, List<BaseItemDto> tracks, int index) {
    final item = results[index];
    if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.track) {
      return TrackListTile(
        key: ValueKey(item.id),
        item: item,
        showIndex: false,
        showCover: true,
        // Index of this track within the queueable tracks, used to start
        // playback at the tapped track.
        index: tracks.indexWhere((t) => t.id == item.id),
        parentPlayable: PrecalculatedPlayable(
          source: QueueItemSource.rawId(
            type: QueueItemSourceType.unknown,
            name: QueueItemSourceName(
              type: QueueItemSourceNameType.preTranslated,
              pretranslatedName:
                  MaterialLocalizations.of(context).searchFieldLabel,
            ),
            id: "universal-search",
          ),
          // Only the tracks in the results should be queueable together.
          tracks: tracks,
        ),
      );
    }

    // ItemWrapper handles tap navigation (artist/album/playlist/genre screens)
    // and the long-press context menu.
    return ItemWrapper(
      key: ValueKey(item.id),
      item: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: MaterialLocalizations.of(context).searchFieldLabel,
          ),
        ),
        scrolledUnderElevation: 0,
      ),
      body: isOffline
          ? Center(child: Text(context.l10n.notAvailableInOfflineMode))
          : _searchFuture == null
              ? const SizedBox.shrink()
              : FutureBuilder<List<BaseItemDto>>(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final results = snapshot.data ?? [];
                    if (results.isEmpty) {
                      return Center(child: Text(context.l10n.nothingFoundToPlay));
                    }

                    final tracks = results
                        .where((i) => BaseItemDtoType.fromItem(i) == BaseItemDtoType.track)
                        .toList();

                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      itemBuilder: (context, index) =>
                          _buildResultItem(results, tracks, index),
                    );
                  },
                ),
    );
  }
}
