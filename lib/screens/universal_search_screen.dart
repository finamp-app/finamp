import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../components/AlbumScreen/track_list_tile.dart';
import '../components/MusicScreen/item_collection_wrapper.dart';
import '../l10n/app_localizations.dart';
import '../models/finamp_models.dart';
import '../models/jellyfin_models.dart';
import '../services/finamp_settings_helper.dart';
import '../services/jellyfin_api_helper.dart';

class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({Key? key}) : super(key: key);

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
    if (FinampSettingsHelper.finampSettings.isOffline) {
      return [];
    }

    final results = await _jellyfinApiHelper.getItems(
      includeItemTypes:
          "Audio,MusicAlbum,MusicArtist,Playlist,MusicGenre",
      searchTerm: query,
      sortBy: "SortName",
      sortOrder: "Ascending",
      startIndex: 0,
      limit: 100,
    );

    return results ?? [];
  }

  Widget _buildResultItem(BaseItemDto item) {
    final itemType = BaseItemDtoType.fromItem(item);
    if (itemType == BaseItemDtoType.track || item.type == "Audio") {
      return TrackListTile(
        item: item,
        isTrack: true,
        isShownInSearchOrHistory: true,
        showIndex: false,
        showCover: true,
      );
    }

    return ItemCollectionWrapper(
      item: item,
      isPlaylist: item.type == "Playlist",
      isGrid: false,
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
            ? Center(
                child: Text(AppLocalizations.of(context)!.notAvailableInOfflineMode),
              )
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
                        return const Center(child: Text("No results"));
                      }

                      return ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: results.length,
                        itemBuilder: (context, index) =>
                            _buildResultItem(results[index]),
                      );
                    },
                  ),
    );
  }
}
