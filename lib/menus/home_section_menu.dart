import 'dart:async';

import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/menus/components/menuEntries/edit_home_section_menu_entry.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/menus/components/menu_item_info_header.dart';
import 'package:finamp/menus/components/playbackActions/playback_action_row.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

const Duration albumMenuDefaultAnimationDuration = Duration(milliseconds: 750);
const Curve albumMenuDefaultInCurve = Curves.easeOutCubic;
const Curve albumMenuDefaultOutCurve = Curves.easeInCubic;
const albumMenuRouteName = "/album-menu";

Future<void> showModalHomeSectionMenu({
  required BuildContext context,
  required HomeScreenSectionConfiguration section,
}) async {
  final item = HomeScreenPlayable(
    config: section,
    item: section.type == HomeScreenSectionType.collection
        ? await GetIt.instance<ProviderContainer>().read(itemByIdProvider(section.itemId).future)
        : null,
  );

  final showPlayback = section.contentType == TabContentType.tracks;

  // Normal menu entries, excluding headers
  List<HideableMenuEntry> getMenuEntries(BuildContext context) {
    return [EditHomeSectionMenuEntry(section: section)];
  }

  (double, List<Widget>) getMenuProperties(BuildContext context) {
    final menuEntries = getMenuEntries(context);
    final stackHeight = ThemedBottomSheet.calculateStackHeight(
      context: context,
      menuEntries: menuEntries,
      includePlaybackRow: showPlayback,
    );
    List<Widget> menu = [
      SliverPersistentHeader(delegate: MenuItemInfoSliverHeader(item: item), pinned: true),
      if (showPlayback)
        MenuMask(
          height: MenuItemInfoSliverHeader.defaultHeight,
          child: SliverToBoxAdapter(child: PlaybackActionRow(item: item)),
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
    routeName: albumMenuRouteName,
    buildSlivers: (context) => getMenuProperties(context),
  );
}
