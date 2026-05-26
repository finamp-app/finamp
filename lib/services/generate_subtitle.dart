import 'package:collection/collection.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../models/jellyfin_models.dart';
import 'process_artist.dart';

/// Creates the subtitle text used on ItemCollectionListTile and ItemCollectionCard
String? generateSubtitle({
  required BuildContext context,
  required BaseItemDto item,
  String? parentType,
  ArtistType? artistType,
}) {
  // If the parentType is MusicArtist, this is being called by an ItemCollectionListTile in an AlbumView of an artist.
  if (parentType == "MusicArtist") {
    return ReleaseDateHelper.autoFormat(item);
  }

  switch (BaseItemDtoType.fromItem(item)) {
    case BaseItemDtoType.album:
      return item.albumArtists != null &&
              item.albumArtists!.isNotEmpty &&
              (item.albumArtists!.length > 1 || item.albumArtists?.first.name != item.albumArtist)
          ? item.albumArtists!.sortedBy((e) => e.name ?? '').map((e) => processArtist(e.name, context)).join(", ")
          : processArtist(item.albumArtist, context);
    case BaseItemDtoType.playlist:
      return AppLocalizations.of(context)!.trackCount(item.childCount!);
    // case BaseItemDtoType.genre:
    // Currently, for each album Jellyfin only increases the childCount of ONE album-artist
    // If there are multiple, we get incorrect childCounts on those (and if they only have albums
    // together with other albumArtists, we get a count of NULL). Unfortunately, the "songCount"
    // currently returns NULL as well, so instead of showing incomplete or incorrect data, we leave
    // this uncommented for now until this issue is fixed server-side.
    //case BaseItemDtoType.artist:
    //  if (artistType != null && artistType == ArtistType.artist) {
    //    return (item.songCount != null) ? AppLocalizations.of(context)!.trackCount(item.songCount!) : null;
    //  }
    //  return (item.childCount != null) ? AppLocalizations.of(context)!.albumCount(item.childCount!) : null;
    default:
      return null;
  }
}
