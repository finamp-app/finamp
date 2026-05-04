import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/PlayerScreen/genre_chip.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/datetime_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/jellyfin_models.dart';
import '../format_bytes.dart';
import '../icon_and_text.dart';
import '../print_duration.dart';

class ItemInfo extends ConsumerWidget {
  const ItemInfo({super.key, required this.item, required this.itemTracks, this.genreFilter, this.updateGenreFilter});

  final BaseItemDto item;
  final List<BaseItemDto> itemTracks;
  final BaseItemDto? genreFilter;
  final void Function(BaseItemDto?)? updateGenreFilter;

  // TODO: see if there's a way to expand this column to the row that it's in
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(finampSettingsProvider.isOffline);
    final itemTracksCount = itemTracks.length;
    final trackCountString = (itemTracks.length == item.childCount || !isOffline)
        ? AppLocalizations.of(context)!.trackCount(itemTracksCount)
        : AppLocalizations.of(context)!.offlineTrackCount(item.childCount!, itemTracksCount);
    final trackDurationString = (genreFilter == null && (itemTracks.length == item.childCount))
        ? "$trackCountString (${printDuration(item.runTimeTicksDuration())})"
        : "$trackCountString (${printDuration(itemTracks.map((t) => t.runTimeTicksDuration()).whereType<Duration>().fold<Duration>(Duration.zero, (sum, dur) => sum + dur))})";

    // Sum the size of every track that has it; if no track reports a size,
    // skip showing the row entirely (mirrors the maintainer's "only if the
    // server gives us the size" guidance from #1146). The size lives on
    // each track's first MediaSourceInfo rather than on BaseItemDto itself.
    final totalSizeBytes = itemTracks.fold<int>(0, (sum, t) {
      final sources = t.mediaSources;
      final trackBytes = (sources != null && sources.isNotEmpty) ? (sources.first.size ?? 0) : 0;
      return sum + trackBytes;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // We display the title of a playlist here,
        // because we have too many actions in the AppBar
        if (item.type == "Playlist")
          Padding(
            padding: EdgeInsets.only(left: 6, right: 6, top: 0, bottom: 6),
            child: Text(
              item.name ?? "Unknown Playlist",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: Theme.of(context).textTheme.titleMedium!.fontSize! + 1),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (item.type != "Playlist") ArtistChips(baseItem: item, artistType: ArtistType.albumArtist),
        IconAndText(
          iconData: Icons.music_note,
          textSpan: TextSpan(text: trackDurationString),
        ),
        if (totalSizeBytes > 0)
          IconAndText(
            iconData: Icons.sd_storage,
            textSpan: TextSpan(text: formatBytes(totalSizeBytes)),
          ),
        if (item.type != "Playlist")
          IconAndText(
            iconData: Icons.event,
            textSpan: TextSpan(text: ReleaseDateHelper.autoFormat(item) ?? AppLocalizations.of(context)!.noReleaseDate),
          ),
        Row(
          children: [
            Expanded(
              child: GenreIconAndText(parent: item, genreFilter: genreFilter, updateGenreFilter: updateGenreFilter),
            ),
          ],
        ),
      ],
    );
  }
}
