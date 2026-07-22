import 'dart:async';

import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/menus/components/menuEntries/adaptive_download_lock_delete_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/add_to_playlist_menu_entry.dart';
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
import 'package:flutter/material.dart';

import '../models/music_models.dart';

const Duration collectionMenuDefaultAnimationDuration = Duration(milliseconds: 750);
const Curve collectionMenuDefaultInCurve = Curves.easeOutCubic;
const Curve collectionMenuDefaultOutCurve = Curves.easeInCubic;
const collectionMenuRouteName = "/collection-menu";

Future<void> showModalCollectionMenu({
  required BuildContext context,
  required BaseItemDto item,
  FinampStorableQueueInfo? queueInfo,
}) async {
  final playableItem = JellyfinCollection.fromItem(item);
  // Normal menu entries, excluding headers
  List<HideableMenuEntry> getMenuEntries(BuildContext context) {
    return [
      if (queueInfo != null) RestoreQueueMenuEntry(queueInfo: queueInfo),
      // AddToPlaylistMenuEntry(item: playableItem),
      InstantMixMenuEntry(baseItem: item),
      // MixBuilderMenuEntry(baseItem: item),
      StartRadioMenuEntry(baseItem: item),
      // AdaptiveDownloadLockDeleteMenuEntry(baseItem: item),
      ToggleFavoriteMenuEntry(baseItem: item),
    ];
  }

  (double, List<Widget>) getMenuProperties(BuildContext context) {
    final menuEntries = getMenuEntries(context);
    final stackHeight = ThemedBottomSheet.calculateStackHeight(context: context, menuEntries: menuEntries);

    List<Widget> menu = [
      SliverPersistentHeader(delegate: MenuItemInfoSliverHeader(item: playableItem), pinned: true),
      MenuMask(
        height: MenuItemInfoSliverHeader.defaultHeight,
        child: SliverToBoxAdapter(child: PlaybackActionRow(item: playableItem)),
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
    item: item,
    routeName: collectionMenuRouteName,
    buildSlivers: (context) => getMenuProperties(context),
  );
}
