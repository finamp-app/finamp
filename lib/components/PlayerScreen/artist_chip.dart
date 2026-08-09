import 'package:collection/collection.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/jellyfin_models.dart';
import '../../screens/artist_screen.dart';
import '../../services/downloads_service.dart';
import '../../services/finamp_settings_helper.dart';
import '../../services/jellyfin_api_helper.dart';
import '../album_image.dart';

part 'artist_chip.g.dart';

const _radius = Radius.circular(4);
const _borderRadius = BorderRadius.all(_radius);
const _height = 24.0; // I'm sure this magic number will work on all devices
final _defaultBackgroundColour = Colors.white.withOpacity(0.1);

@riverpod
Future<BaseItemDto?> artistItem(Ref ref, BaseItemId id) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final isarDownloader = GetIt.instance<DownloadsService>();
  final bool isOffline = ref.watch(finampSettingsProvider.isOffline);
  return isOffline
      ? isarDownloader.getCollectionInfo(id: id).then((value) => value?.baseItem)
      : jellyfinApiHelper.getItemById(id);
}

class ArtistChips extends StatelessWidget {
  const ArtistChips({super.key, this.backgroundColor, this.color, this.baseItem, this.artistType = ArtistType.artist});

  final BaseItemDto? baseItem;
  final Color? backgroundColor;
  final Color? color;
  final ArtistType artistType;

  @override
  Widget build(BuildContext context) {
    final artists = ((artistType == ArtistType.albumArtist) ? baseItem?.albumArtists : baseItem?.artistItems) ?? [];
    final filteredArtists = {
      for (var artist in artists) artist.id: artist,
    }.values.sortedBy((e) => e.name ?? '').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: filteredArtists.isEmpty
              ? [ArtistChip(backgroundColor: backgroundColor, color: color, artist: null, key: const ValueKey(null))]
              : List.generate(filteredArtists.length, (index) {
                  final currentArtist = filteredArtists[index];

                  return ArtistChip(
                    backgroundColor: backgroundColor,
                    color: color,
                    artist: BaseItemDto(id: currentArtist.id, name: currentArtist.name, type: "MusicArtist"),
                    key: ValueKey(currentArtist.id),
                  );
                }),
        ),
      ),
    );
  }
}

class ArtistChip extends ConsumerWidget {
  const ArtistChip({super.key, this.backgroundColor, this.color, this.artist});

  final BaseItemDto? artist;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localBackgroundColor = backgroundColor ?? _defaultBackgroundColour;
    final localColor = color ?? Theme.of(context).textTheme.bodySmall?.color ?? Colors.white;
    final BaseItemDto? localArtist;
    if (artist != null && ref.watch(finampSettingsProvider.showArtistChipImage)) {
      localArtist = ref.watch(artistItemProvider(artist!.id)).valueOrNull ?? artist;
    } else {
      localArtist = artist;
    }
    return _ArtistChipContent(item: localArtist, backgroundColor: localBackgroundColor, color: localColor);
  }
}

class _ArtistChipContent extends StatelessWidget {
  const _ArtistChipContent({required this.item, required this.backgroundColor, required this.color});

  final BaseItemDto? item;
  final Color backgroundColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // We do this so that we can pass the track item here to show an actual value
    // instead of empty
    bool isArtist = item?.isArtist ?? false;
    final name = isArtist ? item?.name : (item?.artists?.firstOrNull ?? item?.albumArtist);

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: "$name (${AppLocalizations.of(context)!.artist})", button: true),
      container: true,
      child: SizedBox(
        height: _height,
        child: Material(
          color: backgroundColor,
          borderRadius: _borderRadius,
          child: InkWell(
            // We shouldn't click through to artists if not passed one
            onTap: !isArtist ? null : () => Navigator.of(context).pushNamed(ArtistScreen.routeName, arguments: item),
            borderRadius: _borderRadius,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isArtist && item?.imageId != null)
                  AlbumImage(
                    item: item,
                    borderRadius: const BorderRadius.only(topLeft: _radius, bottomLeft: _radius),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      name ?? AppLocalizations.of(context)!.unknownArtist,
                      style: TextStyle(color: color, overflow: TextOverflow.ellipsis),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
