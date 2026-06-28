import 'dart:async';

import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/menus/components/menuEntries/adaptive_download_lock_delete_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/add_to_playlist_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/delete_from_server_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/instant_mix_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/mix_builder_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/restore_queue_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/start_radio_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/toggle_favorite_menu_entry.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:flutter/material.dart';

const Duration albumMenuDefaultAnimationDuration = Duration(milliseconds: 750);
const Curve albumMenuDefaultInCurve = Curves.easeOutCubic;
const Curve albumMenuDefaultOutCurve = Curves.easeInCubic;
const albumMenuRouteName = "/album-menu";

Future<void> showModalAlbumMenu({
  required BuildContext context,
  required FinampPlayable album,
  FinampStorableQueueInfo? queueInfo,
}) async {
  final BaseItemDto baseItem = switch (album) {
    AlbumDisc() => album.item,
    Album() => album.item,
    _ => throw UnsupportedError("Cannot show album menu for item $album"),
  };

  // Normal menu entries, excluding headers
  List<HideableMenuEntry> getMenuEntries(BuildContext context) {
    return [
      if (queueInfo != null) RestoreQueueMenuEntry(queueInfo: queueInfo),
      AddToPlaylistMenuEntry(item: album),
      if (album is Album) ...[
        // instant mixes from arbitrary collection of tracks is not supported
        InstantMixMenuEntry(baseItem: baseItem),
        MixBuilderMenuEntry(baseItem: baseItem),
        // radio requires a [BaseItemDto] as the source
        StartRadioMenuEntry(baseItem: baseItem),
        // download system is not that flexible
        AdaptiveDownloadLockDeleteMenuEntry(baseItem: baseItem),
        // backend is not flexible too
        ToggleFavoriteMenuEntry(baseItem: baseItem),
        DeleteFromServerMenuEntry(baseItem: baseItem),
      ],
    ];
  }

  (double, List<Widget>) getMenuProperties(BuildContext context) {
    final menuEntries = getMenuEntries(context);
    final stackHeight = ThemedBottomSheet.calculateStackHeight(context: context, menuEntries: menuEntries);
    List<Widget> menu = [
      SliverPersistentHeader(delegate: MenuItemInfoSliverHeader(item: album), pinned: true),
      MenuMask(
        height: MenuItemInfoSliverHeader.defaultHeight,
        child: SliverToBoxAdapter(child: PlaybackActionRow(item: album)),
      ),
      MenuMask(
        height: MenuItemInfoSliverHeader.defaultHeight,
        child: SliverPadding(
          padding: const EdgeInsets.only(left: 8.0),
          sliver: SliverList(delegate: SliverChildListDelegate(menuEntries)),
        ),
      ),
    ];

    return (stackHeight, menu);
  }

  await showThemedBottomSheet(
    context: context,
    item: baseItem,
    routeName: albumMenuRouteName,
    buildSlivers: (context) => getMenuProperties(context),
  );
}
