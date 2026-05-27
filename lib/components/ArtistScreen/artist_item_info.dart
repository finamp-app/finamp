import 'package:finamp/components/PlayerScreen/genre_chip.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../models/jellyfin_models.dart';
import '../icon_and_text.dart';

class ArtistItemInfo extends ConsumerWidget {
  const ArtistItemInfo({
    super.key,
    required this.item,
    required this.itemTracks,
    required this.itemAlbums,
    this.updateGenreFilter,
  });

  final BaseItemDto item;
  final int itemTracks;
  final int itemAlbums;
  final void Function(BaseItemDto?)? updateGenreFilter;

  // TODO: see if there's a way to expand this column to the row that it's in
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconAndText(
          iconData: Icons.music_note,
          textSpan: TextSpan(
            text: ref.watch(finampSettingsProvider.isOffline)
                ? AppLocalizations.of(context)!.offlineTrackCountArtist(itemTracks)
                : AppLocalizations.of(context)!.trackCount(itemTracks),
          ),
        ),
        IconAndText(
          iconData: TablerIcons.disc,
          textSpan: TextSpan(text: AppLocalizations.of(context)!.albumCount(itemAlbums)),
        ),
        if (BaseItemDtoType.fromItem(item) != BaseItemDtoType.genre && item.genreItems != null)
          GenreIconAndText(parent: item, updateGenreFilter: updateGenreFilter),
      ],
    );
  }
}
