import 'package:collection/collection.dart';
import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_list.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/components/toggleable_list_tile.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/favorite_provider.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

const playlistActionsMenuRouteName = "/playlist-actions-menu";

Future<void> showPlaylistActionsMenu({
  required BuildContext context,
  required List<BaseItemDto> items,
  BaseItemDto? parentPlaylist,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  FeedbackHelper.feedback(FeedbackType.selection);

  var playlistsFuture = jellyfinApiHelper.getItems(includeItemTypes: "Playlist", sortBy: "SortName");

  await showThemedBottomSheet(
    context: context,
    item: items.length == 1 ? items.first : null,
    routeName: playlistActionsMenuRouteName,
    minDraggableHeight: 0.2,
    buildSlivers: (context) {
      var themeColor = Theme.of(context).colorScheme.primary;

      final menuEntries = [
        if (items.length == 1) MenuItemInfoHeader.condensed(item: FinampPlayableDto.fromItem(items.first)),
        if (items.length == 1) const SizedBox(height: 16),
        if (items.length == 1)
          Consumer(
            builder: (context, ref, child) {
              bool isFavorite = ref.watch(isFavoriteProvider(items.first));
              return PlaylistActionsPlaylistListTile(
                title: AppLocalizations.of(context)!.favorites,
                leading: AspectRatio(
                  aspectRatio: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: themeColor.withOpacity(0.3)),
                    child: const Center(child: Icon(TablerIcons.heart, size: 36.0, color: Colors.white)),
                  ),
                ),
                positiveIcon: TablerIcons.heart_filled,
                negativeIcon: TablerIcons.heart,
                initialState: isFavorite,
                tapFeedback: false,
                onToggle: (bool currentState) async {
                  return ref.read(isFavoriteProvider(items.first).notifier).updateFavorite(!isFavorite);
                },
                enabled: !ref.watch(finampSettingsProvider.isOffline),
              );
            },
          ),
        FutureBuilder(
          future: playlistsFuture.then((value) => value?.firstWhereOrNull((x) => x.id == parentPlaylist?.id)),
          initialData: parentPlaylist,
          builder: (context, snapshot) {
            if (snapshot.data != null) {
              return AddToPlaylistTile(
                playlist: snapshot.data!,
                itemsToBeAdded: items,
                playlistItemId: items.length == 1 ? items.first.playlistItemId : null,
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ];

      var menu = [
        SliverStickyHeader(
          header: const PlaylistActionsMenuHeader(),
          sliver: MenuMask(
            height: PlaylistActionsMenuHeader.defaultHeight,
            child: SliverList(delegate: SliverChildListDelegate(menuEntries)),
          ),
        ),
        SliverStickyHeader(
          header: Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Text(
              AppLocalizations.of(context)!.addPlaylistSubheader,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          sliver: MenuMask(
            height: PlaylistActionsMenuHeader.defaultHeight,
            child: AddToPlaylistList(
              itemsToAdd: items,
              playlistsFuture: playlistsFuture.then(
                (value) => (value?.where((element) => element.id != parentPlaylist?.id).toList() ?? []),
              ),
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100.0)),
      ];
      // TODO better estimate, how to deal with lag getting playlists?
      var stackHeight = MediaQuery.heightOf(context) * 0.9;
      return (stackHeight, menu);
    },
  );
}

class PlaylistActionsMenuHeader extends ConsumerWidget {
  const PlaylistActionsMenuHeader({super.key});
  static MenuMaskHeight defaultHeight = MenuMaskHeight(35.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.addRemoveFromPlaylist,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class PlaylistActionsPlaylistListTile extends ConsumerStatefulWidget {
  const PlaylistActionsPlaylistListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.leading,
    this.positiveIcon,
    this.negativeIcon,
    required this.initialState,
    required this.onToggle,
    this.enabled = true,
    this.forceLoading = false,
    this.tapFeedback = true,
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final IconData? positiveIcon;
  final IconData? negativeIcon;
  final bool initialState;
  final Future<bool> Function(bool currentState) onToggle;
  final bool enabled;
  final bool forceLoading;
  final bool tapFeedback;

  @override
  ConsumerState<PlaylistActionsPlaylistListTile> createState() => _PlaylistActionsPlaylistListTileState();
}

class _PlaylistActionsPlaylistListTileState extends ConsumerState<PlaylistActionsPlaylistListTile> {
  bool isLoading = false;
  bool currentState = false;

  @override
  void initState() {
    super.initState();
    currentState = widget.initialState;
  }

  @override
  void didUpdateWidget(PlaylistActionsPlaylistListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forceLoading) {
      currentState = widget.initialState;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToggleableListTile(
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subtitle,
      state: currentState,
      onToggle: (bool newState) async {
        setState(() {
          isLoading = true;
        });
        try {
          final confirmedState = await widget.onToggle(newState);
          setState(() {
            isLoading = false;
            currentState = confirmedState;
          });
        } catch (e) {
          setState(() {
            isLoading = false;
          });
          GlobalSnackbar.error(e);
        }
      },
      isLoading: isLoading,
      icon: currentState ? widget.positiveIcon : widget.negativeIcon,
      enabled: widget.enabled,
      confirmationFeedback: widget.tapFeedback,
    );
  }
}
