import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';
import '../../models/jellyfin_models.dart';
import '../../screens/album_screen.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';

final _borderRadius = BorderRadius.circular(4);

class AlbumChips extends StatelessWidget {
  const AlbumChips({super.key, this.baseItem, this.backgroundColor, this.color, this.includeReleaseDate});

  final BaseItemDto? baseItem;
  final Color? backgroundColor;
  final Color? color;
  final bool? includeReleaseDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AlbumChip(
          key: const ValueKey(null),
          includeReleaseDate: includeReleaseDate,
          backgroundColor: backgroundColor,
          color: color,
          item: baseItem,
        ),
      ),
    );
  }
}

class AlbumChip extends StatelessWidget {
  const AlbumChip({super.key, this.item, this.backgroundColor, this.color, this.includeReleaseDate});

  final BaseItemDto? item;
  final Color? backgroundColor;
  final Color? color;
  final bool? includeReleaseDate;

  @override
  Widget build(BuildContext context) {
    if (item == null) return const _EmptyAlbumChip();

    return Container(
      constraints: const BoxConstraints(minWidth: 10),
      child: _AlbumChipContent(
        item: item!,
        color: color,
        backgroundColor: backgroundColor,
        includeReleaseDate: includeReleaseDate,
      ),
    );
  }
}

class _EmptyAlbumChip extends StatelessWidget {
  const _EmptyAlbumChip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 64, height: 20, child: Material(borderRadius: _borderRadius));
  }
}

class ReleaseDate extends StatelessWidget {
  const ReleaseDate({super.key, this.baseItem, this.backgroundColor, this.color, this.inParentheses = false});

  final BaseItemDto? baseItem;
  final Color? backgroundColor;
  final Color? color;
  final bool inParentheses;

  @override
  Widget build(BuildContext context) {
    final releaseDate = ReleaseDateHelper.autoFormat(baseItem);

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: "Release date: $releaseDate", button: true),
      excludeSemantics: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
        child: Text(
          inParentheses ? "(${releaseDate ?? context.l10n.unknown})" : releaseDate ?? context.l10n.unknown,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(color: color ?? Theme.of(context).textTheme.bodySmall!.color ?? Colors.white),
        ),
      ),
    );
  }
}

class _AlbumChipContent extends ConsumerWidget {
  const _AlbumChipContent({
    required this.item,
    required this.backgroundColor,
    required this.color,
    this.includeReleaseDate,
  });

  final BaseItemDto item;
  final Color? backgroundColor;
  final Color? color;
  final bool? includeReleaseDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final isarDownloader = GetIt.instance<DownloadsService>();

    final albumName = item.album ?? AppLocalizations.of(context)!.noAlbum;

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: "$albumName (${AppLocalizations.of(context)!.album})", button: true),
      excludeSemantics: true,
      container: true,
      child: Material(
        color: backgroundColor ?? Colors.white.withOpacity(0.1),
        borderRadius: _borderRadius,
        child: InkWell(
          borderRadius: _borderRadius,
          onTap: item.albumId != null
              ? () async {
                  if (FinampSettingsHelper.finampSettings.isOffline) {
                    var stub = await isarDownloader.getCollectionInfo(id: item.albumId!);
                    if (stub?.baseItem != null && context.mounted) {
                      await Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: stub!.baseItem!);
                    }
                  } else {
                    var album = await jellyfinApiHelper.getItemById(item.albumId!);
                    if (context.mounted) {
                      await Navigator.of(context).pushNamed(AlbumScreen.routeName, arguments: album);
                    }
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              spacing: 2.0,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  albumName,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(color: color ?? Theme.of(context).textTheme.bodySmall!.color ?? Colors.white),
                ),
                if ((includeReleaseDate ?? ref.watch(finampSettingsProvider.showAlbumReleaseDateOnPlayerScreen)) &&
                    ReleaseDateHelper.autoFormat(item) != null)
                  ReleaseDate(baseItem: item, color: color, inParentheses: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
