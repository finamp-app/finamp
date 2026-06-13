import 'package:collection/collection.dart';
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
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../extensions/localizations.dart';
import '../../services/item_helper.dart';

const double infoHeaderFullExtent = 162.0;
const double infoHeaderFullInternalHeight = 140.0;
const double infoHeaderCondensedInternalHeight = 80.0;

Widget _getMenuHeaderForItemType({
  required FinampDisplayableOrPlayable item,
  required bool condensed,
  required List<MenuItemInfoHeaderFeatures> features,
  required BuildContext context,
}) {
  return switch (item) {
    AlbumDisc() => AlbumInfo(item: item, condensed: condensed, features: features),
    FinampPlayableDto(item: final baseItem) => switch (BaseItemDtoType.fromItem(baseItem)) {
      BaseItemDtoType.track => TrackInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.album => AlbumInfo(item: item, condensed: condensed, features: features),
      BaseItemDtoType.playlist => PlaylistInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.genre => GenreInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.artist => ArtistInfo(item: baseItem, condensed: condensed, features: features),
      BaseItemDtoType.collection => CollectionInfo(item: baseItem, condensed: condensed, features: features),
      _ => TrackInfo(item: baseItem, condensed: condensed, features: features),
    },
    MusicScreenPlayable(sortConfig: final config, library: final library, tab: final content) => HomeSectionInfo(
      config: HomeScreenSectionConfiguration(
        base: TabsHomeSection(libraryId: library, contentType: content),
        sortConfig: config,
        customSectionTitle: item.source.name.getLocalized(context.l10n),
      ),
    ),
    LatestQueues() => HomeSectionInfo(
      config: HomeScreenSectionConfiguration(
        base: QueuesHomeSection(),
        sortConfig: SortAndFilterConfiguration.defaultSort,
        customSectionTitle: item.source.name.getLocalized(context.l10n),
      ),
    ),
    _ => throw UnsupportedError("Cannot show menu header for $item"),
  };
}

enum MenuItemInfoHeaderFeatures { artwork, openItem, addToPlaylistAndFavorite }

class MenuItemInfoSliverHeader extends SliverPersistentHeaderDelegate {
  final FinampDisplayableOrPlayable item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  MenuItemInfoSliverHeader({
    required this.item,
    this.features = const [
      MenuItemInfoHeaderFeatures.artwork,
      MenuItemInfoHeaderFeatures.openItem,
      MenuItemInfoHeaderFeatures.addToPlaylistAndFavorite,
    ],
  }) : condensed = false;

  MenuItemInfoSliverHeader.condensed({
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.artwork, MenuItemInfoHeaderFeatures.openItem],
  }) : condensed = true;

  MenuItemInfoSliverHeader.noArtwork({required this.item, this.features = const [MenuItemInfoHeaderFeatures.openItem]})
    : condensed = false;

  MenuItemInfoSliverHeader.condensedNoArtwork({
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.openItem],
  }) : condensed = true;

  static const MenuMaskHeight defaultHeight = MenuMaskHeight(151.0);
  static const MenuMaskHeight condensedHeight = MenuMaskHeight(80.0);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _getMenuHeaderForItemType(item: item, condensed: condensed, features: features, context: context);
  }

  @override
  double get maxExtent => (condensed ? condensedHeight.raw : defaultHeight.raw) + 10.0;

  @override
  double get minExtent => (condensed ? condensedHeight.raw : defaultHeight.raw) + 10.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class MenuItemInfoHeader extends ConsumerWidget {
  final FinampDisplayableOrPlayable item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  const MenuItemInfoHeader({
    super.key,
    required this.item,
    this.features = const [
      MenuItemInfoHeaderFeatures.artwork,
      MenuItemInfoHeaderFeatures.openItem,
      MenuItemInfoHeaderFeatures.addToPlaylistAndFavorite,
    ],
  }) : condensed = false;

  const MenuItemInfoHeader.condensed({
    super.key,
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.artwork, MenuItemInfoHeaderFeatures.openItem],
  }) : condensed = true;

  const MenuItemInfoHeader.noArtwork({
    super.key,
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.openItem],
  }) : condensed = false;

  const MenuItemInfoHeader.condensedNoArtwork({
    super.key,
    required this.item,
    this.features = const [MenuItemInfoHeaderFeatures.openItem],
  }) : condensed = true;

  static const MenuMaskHeight defaultHeight = MenuMaskHeight(152.0);
  static const MenuMaskHeight condensedHeight = MenuMaskHeight(35.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _getMenuHeaderForItemType(item: item, condensed: condensed, features: features, context: context);
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
      features: features.whereNot((feature) => feature == MenuItemInfoHeaderFeatures.openItem).toList(),
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

  final FinampDisplayableOrPlayable item;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = this.item;
    final String title;
    final BaseItemDto baseItem;

    switch (item) {
      case AlbumDisc():
        baseItem = item.item;
        title = AppLocalizations.of(context)!.discOfAlbum(
          item.tracks.first.parentIndexNumber!,
          baseItem.name ?? AppLocalizations.of(context)!.unknownName,
        );
      case Album():
        baseItem = item.item;
        title = baseItem.name ?? AppLocalizations.of(context)!.unknownName;
      case _:
        throw UnsupportedError("Unexpected type $item in album info header");
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

class CollectionInfo extends ConsumerWidget {
  const CollectionInfo({super.key, required this.item, required this.condensed, required this.features});

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
    required this.featureImage,
    required this.infoRows,
    required this.features,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  });

  final BaseItemDto item;
  final bool condensed;
  final ShapeBorder shape;
  final AlbumImage featureImage;
  final List<Widget> infoRows;
  final List<MenuItemInfoHeaderFeatures> features;

  @override
  Widget build(BuildContext context) {
    return _getGenericMenuInfo(
      context,
      condensed: condensed,
      features: features,
      featureImage: featureImage,
      item: item,
      onOpen: () => openItemPage(item, Navigator.of(context)),
      shape: shape,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: infoRows,
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
    AlbumImage? image;
    if (item != null && config.base is CollectionHomeSection) {
      image = AlbumImage(item: item, borderRadius: BorderRadius.zero, tapToZoom: true);
    }

    return _getGenericMenuInfo(
      context,
      condensed: false,
      featureImage: image,
      features: const [MenuItemInfoHeaderFeatures.artwork],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            config.getTitle(context.l10n),
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
            iconData: config.sortConfig.sortOrder.getIcon(),
            textSpan: TextSpan(text: config.sortConfig.sortBy.toLocalisedString(context.l10n)),
          ),
          ...config.sortConfig.filters.map(
            (filter) => IconAndText(
              iconData: TablerIcons.filter,
              textSpan: TextSpan(text: filter.getName(context.l10n)),
            ),
          ),
        ],
      ),
    );
  }
}

class GenericMenuInfoHeader extends StatelessWidget {
  final Widget child;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;
  final AlbumImage? featureImage;
  final BaseItemDto? item;
  final VoidCallback? onOpen;
  final ShapeBorder shape;

  const GenericMenuInfoHeader({
    super.key,
    required this.child,
    required this.condensed,
    this.features = const [],
    this.featureImage,
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  });

  const GenericMenuInfoHeader.condensed({
    super.key,
    required this.child,
    this.features = const [],
    this.featureImage,
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  }) : condensed = true;

  const GenericMenuInfoHeader.noArtwork({
    super.key,
    required this.child,
    this.features = const [],
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  }) : condensed = false,
       featureImage = null;

  const GenericMenuInfoHeader.condensedNoArtwork({
    super.key,
    required this.child,
    this.features = const [],
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  }) : condensed = true,
       featureImage = null;

  @override
  Widget build(BuildContext context) {
    return _getGenericMenuInfo(
      context,
      child: child,
      condensed: condensed,
      features: features,
      featureImage: featureImage,
      item: item,
      onOpen: onOpen,
      shape: shape,
    );
  }
}

class GenericMenuInfoSliverHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool condensed;
  final List<MenuItemInfoHeaderFeatures> features;
  final AlbumImage? featureImage;
  final BaseItemDto? item;
  final VoidCallback? onOpen;
  final ShapeBorder shape;

  const GenericMenuInfoSliverHeader({
    required this.child,
    required this.condensed,
    this.features = const [],
    this.featureImage,
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  });

  const GenericMenuInfoSliverHeader.condensed({
    required this.child,
    this.features = const [],
    this.featureImage,
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  }) : condensed = true;

  const GenericMenuInfoSliverHeader.noArtwork({
    required this.child,
    this.features = const [],
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  }) : condensed = false,
       featureImage = null;

  const GenericMenuInfoSliverHeader.condensedNoArtwork({
    required this.child,
    this.features = const [],
    this.item,
    this.onOpen,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  }) : condensed = true,
       featureImage = null;

  static const MenuMaskHeight defaultHeight = MenuMaskHeight(151.0);
  static const MenuMaskHeight condensedHeight = MenuMaskHeight(80.0);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _getGenericMenuInfo(
      context,
      child: child,
      condensed: condensed,
      features: features,
      featureImage: featureImage,
      item: item,
      onOpen: onOpen,
      shape: shape,
    );
  }

  @override
  double get maxExtent => (condensed ? condensedHeight.raw : defaultHeight.raw) + 10.0;

  @override
  double get minExtent => (condensed ? condensedHeight.raw : defaultHeight.raw) + 10.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

Widget _getGenericMenuInfo(
  BuildContext context, {
  required Widget child,
  required bool condensed,
  List<MenuItemInfoHeaderFeatures> features = const [],
  AlbumImage? featureImage,
  BaseItemDto? item,
  VoidCallback? onOpen,
  ShapeBorder shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
}) {
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
        child: GestureDetector(
          onTap: onOpen,
          child: Stack(
            children: [
              if (features.contains(MenuItemInfoHeaderFeatures.openItem))
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(TablerIcons.external_link, size: 20),
                    padding: const EdgeInsets.all(0.0),
                    visualDensity: VisualDensity(horizontal: -2.0, vertical: -3.0),
                    onPressed: onOpen,
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
                  if (features.contains(MenuItemInfoHeaderFeatures.artwork) && featureImage != null)
                    AspectRatio(aspectRatio: 1.0, child: featureImage),
                  Expanded(
                    child: Container(padding: const EdgeInsets.only(left: 8.0, right: 26.0), child: child),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
