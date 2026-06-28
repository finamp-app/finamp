import 'dart:async';

import 'package:collection/collection.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../menus/playlist_actions_menu.dart';
import '../../models/jellyfin_models.dart';
import '../../services/album_screen_provider.dart';
import '../confirmation_prompt_dialog.dart';
import '../global_snackbar.dart';
import 'new_playlist_dialog.dart';

class AddToPlaylistList extends StatefulWidget {
  const AddToPlaylistList({super.key, required this.itemsToAdd, required this.playlistsFuture});

  final List<BaseItemDto> itemsToAdd;
  final Future<List<BaseItemDto>> playlistsFuture;

  @override
  State<AddToPlaylistList> createState() => _AddToPlaylistListState();
}

class _AddToPlaylistListState extends State<AddToPlaylistList> {
  @override
  void initState() {
    super.initState();
    playlistsFuture = widget.playlistsFuture.then((value) => value.map((e) => (e, false, null as String?)).toList());
  }

  // playlist, isLoading, playlistItemId
  late Future<List<(BaseItemDto, bool, String?)>> playlistsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: playlistsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == snapshot.data!.length) {
                return createNewPlaylistButton(context);
              }
              final (playlist, isLoading, playListItemId) = snapshot.data![index];
              return AddToPlaylistTile(
                playlist: playlist,
                itemsToBeAdded: widget.itemsToAdd,
                playlistItemId: playListItemId,
                isLoading: isLoading,
              );
            }, childCount: snapshot.data!.length + 1),
          );
        } else if (snapshot.hasError) {
          GlobalSnackbar.error(snapshot.error);
          return const SliverToBoxAdapter(child: Center(heightFactor: 3.0, child: Icon(Icons.error, size: 64)));
        } else {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 1) {
                return createNewPlaylistButton(context);
              } else {
                return const Center(child: CircularProgressIndicator.adaptive());
              }
            }, childCount: 2),
          );
        }
      },
    );
  }

  Widget createNewPlaylistButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CTAMedium(
            text: AppLocalizations.of(context)!.newPlaylist,
            icon: TablerIcons.plus,
            //accentColor: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              var itemsToAdd = widget.itemsToAdd;
              // Albums and playlists do not seem to add in the correct order, so manually fetch and add all children instead of
              // relying on server to do that.
              if (itemsToAdd.length == 1 &&
                  [
                    BaseItemDtoType.album,
                    BaseItemDtoType.playlist,
                  ].contains(BaseItemDtoType.fromItem(itemsToAdd.first))) {
                final children = await GetIt.instance<ProviderContainer>().read(
                  getAlbumOrPlaylistTracksProvider(itemsToAdd.first).future,
                );
                itemsToAdd = children.$1;
              }
              var dialogResult = await showDialog<(Future<BaseItemId>, String?)?>(
                context: context,
                builder: (context) => NewPlaylistDialog(
                  itemsToAdd: itemsToAdd.map((item) {
                    return item.id;
                  }).toList(),
                ),
              );
              if (dialogResult != null) {
                var oldFuture = playlistsFuture;
                setState(() {
                  var loadingItem = [
                    (BaseItemDto(id: BaseItemId("pending"), name: dialogResult.$2), true, null as String?),
                  ];
                  playlistsFuture = oldFuture.then((value) => value + loadingItem);
                });
                try {
                  var newId = await dialogResult.$1;
                  // Give the server time to calculate an initial playlist image
                  await Future<void>.delayed(const Duration(seconds: 1));
                  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
                  var playlist = await jellyfinApiHelper.getItemById(newId);

                  String? trackId;
                  if (widget.itemsToAdd.length == 1 &&
                      BaseItemDtoType.fromItem(widget.itemsToAdd.first) == BaseItemDtoType.track) {
                    var playlistItems = await jellyfinApiHelper.getItems(parentItem: playlist, fields: "");
                    trackId = playlistItems
                        ?.firstWhere((element) => element.id == widget.itemsToAdd.first.id)
                        .playlistItemId;
                  } else {
                    // Provide a fake playlist id for playlists created with a non-track initial item.
                    // It will not be used as non-tracks cannot be removed.
                    trackId = "";
                  }
                  if (!context.mounted) return;
                  setState(() {
                    var newItem = [(playlist, false, trackId)];
                    playlistsFuture = oldFuture.then((value) => value + newItem);
                  });
                } catch (e) {
                  GlobalSnackbar.error(e);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class AddToPlaylistTile extends ConsumerStatefulWidget {
  const AddToPlaylistTile({
    super.key,
    required this.playlist,
    this.playlistItemId,
    required this.itemsToBeAdded,
    this.isLoading = false,
  });

  final BaseItemDto playlist;
  final List<BaseItemDto> itemsToBeAdded;
  final String? playlistItemId;
  final bool isLoading;

  @override
  ConsumerState<AddToPlaylistTile> createState() => _AddToPlaylistTileState();
}

class _AddToPlaylistTileState extends ConsumerState<AddToPlaylistTile> {
  String? playlistItemId;
  int? childCount;
  bool? itemIsIncluded;

  @override
  void initState() {
    super.initState();
    _updateState();
  }

  @override
  void didUpdateWidget(AddToPlaylistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateState();
  }

  void _updateState() {
    if (!widget.isLoading) {
      playlistItemId = widget.playlistItemId;
      childCount = widget.playlist.childCount;
      if (widget.playlistItemId != null) {
        itemIsIncluded = true;
      } else {
        final downloadsService = GetIt.instance<DownloadsService>();
        if (widget.itemsToBeAdded.length > 1) {
          itemIsIncluded = false;
        } else {
          itemIsIncluded = downloadsService.checkIfInCollection(widget.playlist, widget.itemsToBeAdded.first);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(finampSettingsProvider.isOffline);
    bool willAddMultipleTracks =
        widget.itemsToBeAdded.length > 1 ||
        BaseItemDtoType.fromItem(widget.itemsToBeAdded.first) != BaseItemDtoType.track;
    bool isMultipleTracks =
        widget.itemsToBeAdded.length > 1 &&
        BaseItemDtoType.fromItem(widget.itemsToBeAdded.first) == BaseItemDtoType.track;
    return PlaylistActionsPlaylistListTile(
      forceLoading: widget.isLoading,
      title: widget.playlist.name ?? AppLocalizations.of(context)!.unknownName,
      subtitle: AppLocalizations.of(context)!.trackCount(childCount ?? 0),
      leading: AlbumImage(item: widget.playlist),
      positiveIcon: TablerIcons.circle_check_filled,
      negativeIcon: itemIsIncluded == null
          // we don't actually know if the track is part of the playlist
          ? TablerIcons.circle_dashed_plus
          : TablerIcons.circle_plus,
      initialState: itemIsIncluded ?? false,
      onToggle: (bool alreadyInPlaylist) async {
        if (alreadyInPlaylist) {
          // Only single tracks can be removed from playlists
          if (willAddMultipleTracks) {
            return true;
          }
          // If playlistItemId is null, we need to fetch from the server before we can remove
          if (playlistItemId == null) {
            final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
            var newItems = await jellyfinApiHelper.getItems(parentItem: widget.playlist, fields: "");

            playlistItemId = newItems?.firstWhereOrNull((x) => x.id == widget.itemsToBeAdded.first.id)?.playlistItemId;
            if (playlistItemId == null) {
              // We were already not part of the playlist,. so removal is complete
              setState(() {
                childCount = newItems?.length ?? 0;
                itemIsIncluded = false;
              });
              return false;
            }
            if (!context.mounted) {
              return true;
            }
          }
          // part of playlist, remove
          bool removed = await removeFromPlaylist(
            context,
            widget.itemsToBeAdded.first,
            widget.playlist,
            playlistItemId!,
            confirm: false,
          );
          if (removed) {
            setState(() {
              childCount = childCount == null ? null : childCount! - 1;
              itemIsIncluded = false;
            });
          }
          return !removed;
        } else {
          // add item collection or multiple tracks to playlist
          if (willAddMultipleTracks) {
            bool confirmed = false;
            String promptText;
            if (isMultipleTracks) {
              promptText = AppLocalizations.of(
                context,
              )!.confirmAddMultipleTracksToPlaylist(widget.itemsToBeAdded.length);
            } else {
              String itemType = switch (BaseItemDtoType.fromItem(widget.itemsToBeAdded.first)) {
                BaseItemDtoType.album => "album",
                BaseItemDtoType.artist => "artist",
                BaseItemDtoType.genre => "genre",
                BaseItemDtoType.playlist => "playlist",
                _ => "unknown",
              };
              promptText = AppLocalizations.of(
                context,
              )!.confirmAddCollectionItemToPlaylist(itemType, widget.itemsToBeAdded.first.name ?? "Unknown");
            }
            await showDialog<void>(
              context: context,
              builder: (context) => ConfirmationPromptDialog(
                promptText: promptText,
                confirmButtonText: AppLocalizations.of(context)!.addButtonLabel,
                onConfirmed: () => confirmed = true,
              ),
            );
            if (!confirmed || !context.mounted) return false;
          }
          bool added = await addItemsToPlaylist(context, widget.itemsToBeAdded, widget.playlist);
          if (added) {
            final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
            var newItems = await jellyfinApiHelper.getItems(parentItem: widget.playlist, fields: "");
            setState(() {
              childCount = newItems?.length ?? 0;
              playlistItemId = newItems
                  ?.firstWhereOrNull((x) => x.id == widget.itemsToBeAdded.first.id)
                  ?.playlistItemId;
              itemIsIncluded = true;
            });
            return true; // this is called before the state is updated
          }
          return false;
        }
      },
      enabled: !isOffline,
    );
  }
}
