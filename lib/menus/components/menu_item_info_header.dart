import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/PlayerScreen/album_chip.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/PlayerScreen/genre_chip.dart';
import 'package:finamp/components/PlayerScreen/item_amount.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/icon_and_text.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../components/finamp_icon.dart';
import '../../services/finamp_settings_helper.dart';

const double infoHeaderFullExtent = 162.0;
const double infoHeaderFullInternalHeight = 140.0;
const double infoHeaderCondensedInternalHeight = 80.0;

Widget _getMenuHeaderForItemType({
  required PlayableItem item,
  required bool condensed,
  required List<MenuItemInfoHeaderFeatures> features,
}) {
  return switch (item) {
    AlbumDisc() => AlbumInfo(item: item, condensed: condensed, features: features),
    PlayableBaseItem(item: final baseItem) => switch (BaseItemDtoType.fromItem(baseItem)) {
      BaseItemDtoType.track => TrackInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.album => AlbumInfo(item: item, condensed: condensed, features: features),
      BaseItemDtoType.playlist => PlaylistInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.genre => GenreInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.artist => ArtistInfo(item: baseItem, condensed: condensed, features: features),
      _ => TrackInfo(item: baseItem, condensed: condensed, features: features),
    },
    HomeScreenPlayable() => HomeSectionInfo(config: item.config, item: item.item),
  };
}

enum MenuItemInfoHeaderFeatures { openItem, addToPlaylistAndFavorite }

class MenuItemInfoSliverHeader extends SliverPersistentHeaderDelegate {
  final PlayableItem item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  MenuItemInfoSliverHeader({
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.openItem, MenuItemInfoHeaderFeatures.addToPlaylistAndFavorite],
  }) : condensed = false;

  MenuItemInfoSliverHeader.condensed({required this.item, this.features = const [MenuItemInfoHeaderFeatures.openItem]})
    : condensed = true;

  static const MenuMaskHeight defaultHeight = MenuMaskHeight(151.0);
  static const MenuMaskHeight condensedHeight = MenuMaskHeight(80.0);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _getMenuHeaderForItemType(item: item, condensed: condensed, features: features);
  }

  @override
  double get maxExtent => (condensed ? condensedHeight.raw : defaultHeight.raw) + 10.0;

  @override
  double get minExtent => (condensed ? condensedHeight.raw : defaultHeight.raw) + 10.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class MenuItemInfoHeader extends ConsumerWidget {
  final BaseItemDto item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  const MenuItemInfoHeader({
    super.key,
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.openItem, MenuItemInfoHeaderFeatures.addToPlaylistAndFavorite],
  }) : condensed = false;

  const MenuItemInfoHeader.condensed({
    super.key,
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.openItem],
  }) : condensed = true;

  static const MenuMaskHeight defaultHeight = MenuMaskHeight(152.0);
  static const MenuMaskHeight condensedHeight = MenuMaskHeight(35.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _getMenuHeaderForItemType(
      item: PlayableBaseItem.defaultSort(item),
      condensed: condensed,
      features: features,
    );
  }
}

class TrackInfo extends ConsumerWidget {
  const TrackInfo({super.key, required this.item, required this.condensed, required this.features});

  final BaseItemDto item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ItemInfo(
      item: item,
      condensed: condensed,
      features: features,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      featureImage: AlbumImage(item: item, borderRadius: BorderRadius.zero, tapToZoom: true),
      infoRows: [
        Text(
          item.name ?? AppLocalizations.of(context)!.unknownName,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: condensed ? 16 : 18,
            height: 1.1,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          maxLines: 2,
        ),
        Padding(
          padding: condensed ? const EdgeInsets.only(top: 6.0) : const EdgeInsets.only(top: 2.0),
          child: ArtistChips(
            baseItem: item,
            backgroundColor:
                IconTheme.of(context).color?.withOpacity(0.1) ??
                Theme.of(context).textTheme.bodyMedium?.color ??
                Colors.white,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
        ),
        if (!condensed) ...[
          AlbumChips(
            baseItem: item,
            backgroundColor:
                IconTheme.of(context).color?.withOpacity(0.1) ??
                Theme.of(context).textTheme.bodyMedium?.color ??
                Colors.white,
            key: item.album == null ? null : ValueKey("${item.album}-album"),
          ),
          GenreIconAndText(parent: item),
        ],
      ],
    );
  }
}

class AlbumInfo extends ConsumerWidget {
  const AlbumInfo({super.key, required this.item, required this.condensed, required this.features});

  final PlayableItem item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
    final String title;
    final BaseItemDto baseItem;

    switch (item) {
      case AlbumDisc():
        baseItem = item.parent;
        title = AppLocalizations.of(context)!.discOfAlbum(
          item.tracks.first.parentIndexNumber!,
          baseItem.name ?? AppLocalizations.of(context)!.unknownName,
        );
      case PlayableBaseItem():
        baseItem = item.item;
        title = baseItem.name ?? AppLocalizations.of(context)!.unknownName;
      case HomeScreenPlayable():
        throw UnimplementedError();
    }

    return ItemInfo(
      item: baseItem,
      condensed: condensed,
      features: features,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      featureImage: AlbumImage(item: baseItem, borderRadius: BorderRadius.zero, tapToZoom: true),
      infoRows: [
        Text(
          title,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: condensed ? 16 : 18,
            height: 1.2,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          maxLines: 2,
        ),
        Padding(
          padding: condensed ? const EdgeInsets.only(top: 6.0) : const EdgeInsets.symmetric(vertical: 0.0),
          child: ArtistChips(
            artistType: ArtistType.albumArtist, // show only album artist for albums
            baseItem: baseItem,
            backgroundColor:
                IconTheme.of(context).color?.withOpacity(0.1) ??
                Theme.of(context).textTheme.bodyMedium?.color ??
                Colors.white,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
        ),
        if (!condensed) ...[
          GenreIconAndText(parent: baseItem),
          IconAndText(
            iconData: Icons.event,
            textSpan: TextSpan(
              text: ReleaseDateHelper.autoFormat(baseItem) ?? AppLocalizations.of(context)!.noReleaseDate,
            ),
          ),
        ],
      ],
    );
  }
}

class PlaylistInfo extends ConsumerWidget {
  const PlaylistInfo({super.key, required this.item, required this.condensed, required this.features});

  final BaseItemDto item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ItemInfo(
      item: item,
      condensed: condensed,
      features: features,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      featureImage: AlbumImage(item: item, borderRadius: BorderRadius.zero, tapToZoom: true),
      infoRows: [
        Text(
          item.name ?? AppLocalizations.of(context)!.unknownName,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: condensed ? 16 : 18,
            height: 1.2,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          maxLines: 2,
        ),
        if (!condensed) ...[
          const SizedBox(height: 4),
          GenreIconAndText(parent: item),
          const SizedBox(height: 4),
          ItemAmount(baseItem: item),
        ],
      ],
    );
  }
}

class ArtistInfo extends ConsumerWidget {
  const ArtistInfo({super.key, required this.item, required this.condensed, required this.features});

  final BaseItemDto item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ItemInfo(
      item: item,
      condensed: condensed,
      features: features,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(MenuItemInfoHeader.defaultHeight / 2),
          bottomLeft: Radius.circular(MenuItemInfoHeader.defaultHeight / 2),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      featureImage: AlbumImage(item: item, borderRadius: BorderRadius.all(Radius.circular(9999)), tapToZoom: true),
      infoRows: [
        Text(
          item.name ?? AppLocalizations.of(context)!.unknownName,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: condensed ? 16 : 18,
            height: 1.2,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          maxLines: 2,
        ),
        if (!condensed) ...[
          const SizedBox(height: 4),
          GenreIconAndText(parent: item),
          const SizedBox(height: 6),
          ItemAmount(baseItem: item),
        ],
      ],
    );
  }
}

class GenreInfo extends ConsumerWidget {
  const GenreInfo({super.key, required this.item, required this.condensed, required this.features});

  final BaseItemDto item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ItemInfo(
      item: item,
      condensed: condensed,
      features: features,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      featureImage: AlbumImage(item: item, borderRadius: BorderRadius.zero, tapToZoom: true),
      infoRows: [
        Text(
          item.name ?? AppLocalizations.of(context)!.unknownName,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: condensed ? 16 : 18,
            height: 1.2,
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          maxLines: 2,
        ),
        if (!condensed) ...[const SizedBox(height: 6), ItemAmount(baseItem: item)],
      ],
    );
  }
}

class ItemInfo extends StatelessWidget {
  const ItemInfo({
    super.key,
    required this.item,
    required this.condensed,
    required this.shape,
    required this.featureImage,
    required this.infoRows,
    required this.features,
  });

  final BaseItemDto item;
  final bool condensed;
  final ShapeBorder shape;
  final AlbumImage featureImage;
  final List<Widget> infoRows;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: condensed ? 28.0 : 12.0),
          height: condensed ? infoHeaderCondensedInternalHeight : infoHeaderFullInternalHeight,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Theme.brightnessOf(context) == Brightness.dark
                ? Colors.black.withOpacity(0.25)
                : Colors.white.withOpacity(0.15),
            shape: shape,
          ),
          child: Stack(
            children: [
              if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.track &&
                  features.contains(MenuItemInfoHeaderFeatures.openItem))
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(TablerIcons.external_link, size: 20),
                    padding: const EdgeInsets.all(0.0),
                    visualDensity: VisualDensity(horizontal: -2.0, vertical: -3.0),
                    onPressed: () {
                      if (BaseItemDtoType.fromItem(item) == BaseItemDtoType.track) {
                        return;
                      }
                      Navigator.pushNamed(context, switch (BaseItemDtoType.fromItem(item)) {
                        BaseItemDtoType.album => AlbumScreen.routeName,
                        BaseItemDtoType.playlist => AlbumScreen.routeName,
                        BaseItemDtoType.genre => GenreScreen.routeName,
                        BaseItemDtoType.artist => ArtistScreen.routeName,
                        _ => AlbumScreen.routeName,
                      }, arguments: item);
                    },
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                  ),
                ),
              if (features.contains(MenuItemInfoHeaderFeatures.addToPlaylistAndFavorite))
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: AddToPlaylistButton(
                    item: item,
                    size: 20,
                    visualDensity: VisualDensity(horizontal: -4.0, vertical: -3.0),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(aspectRatio: 1.0, child: featureImage),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 8.0, right: 26.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: infoRows,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSectionInfo extends ConsumerWidget {
  const HomeSectionInfo({super.key, required this.config, this.item});

  final HomeScreenSectionConfiguration config;
  final BaseItemDto? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget image;
    if (item != null && config.type == HomeScreenSectionType.collection) {
      image = AlbumImage(item: item, borderRadius: BorderRadius.zero, tapToZoom: true);
    } else {
      image = Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorScheme.of(context).primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: FinampIcon(
          70,
          70,
          overrideColor: ref.watch(finampSettingsProvider.isOffline)
              ? TextTheme.of(context).bodyMedium?.color?.withOpacity(0.6)
              : null,
        ),
      );
    }

    return Container(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12.0),
          height: infoHeaderFullInternalHeight,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Theme.brightnessOf(context) == Brightness.dark
                ? Colors.black.withOpacity(0.25)
                : Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AspectRatio(aspectRatio: 1.0, child: image),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 26.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        config.getTitle(context),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        maxLines: 2,
                      ),
                      IconAndText(
                        iconData: config.sortAndFilterConfiguration.sortOrder == SortOrder.ascending
                            ? TablerIcons.sort_ascending
                            : TablerIcons.sort_descending,
                        textSpan: TextSpan(text: config.sortAndFilterConfiguration.sortBy.toLocalisedString(context)),
                      ),
                      ...config.sortAndFilterConfiguration.filters.map(
                        (filter) => IconAndText(
                          iconData: TablerIcons.filter,
                          textSpan: TextSpan(text: filter.getName(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
