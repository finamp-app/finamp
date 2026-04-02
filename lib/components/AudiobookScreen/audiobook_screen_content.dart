import 'package:finamp/components/AlbumScreen/download_button.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/favorite_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../print_duration.dart';
import 'audiobook_flexible_space_bar.dart';

/// The main content widget for an audiobook screen. Displays the book cover,
/// metadata, and a list of chapters (which are AudioBook items in Jellyfin).
class AudiobookScreenContent extends ConsumerStatefulWidget {
  const AudiobookScreenContent({
    super.key,
    required this.parent,
    required this.chapters,
    this.embeddedChapters,
  });

  /// The audiobook (or single AudioBook item) being displayed.
  final BaseItemDto parent;

  /// The list of AudioBook items (chapters/tracks) belonging to this book.
  final List<BaseItemDto> chapters;

  /// Chapter markers read directly from the .m4b file via AVFoundation.
  /// When non-null and non-empty, these are displayed instead of [chapters].
  final List<ChapterInfo>? embeddedChapters;

  @override
  ConsumerState<AudiobookScreenContent> createState() =>
      _AudiobookScreenContentState();
}

class _AudiobookScreenContentState
    extends ConsumerState<AudiobookScreenContent> {
  Widget _buildChapterList(BuildContext context) {
    // Prefer embedded chapter markers (ChapterInfo) from a single-file book
    // (.m4b) extracted via AVFoundation. Fall back to the BaseItemDto list
    // (multi-file / folder books).
    final embedded = widget.embeddedChapters;
    if (embedded != null && embedded.isNotEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ChapterInfoTile(
            chapter: embedded[index],
            index: index,
            parent: widget.parent,
            nextChapterTicks: index + 1 < embedded.length
                ? embedded[index + 1].startPositionTicks
                : (widget.parent.runTimeTicks ?? 0),
          ),
          childCount: embedded.length,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => TrackListTile(
          item: widget.chapters[index],
          children: widget.chapters,
          index: index,
          parentItem: widget.parent,
        ),
        childCount: widget.chapters.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // For single-file books, the total duration is on the parent item itself.
    // For multi-file books, sum the individual chapter durations.
    final Duration totalDuration;
    final embedded = widget.embeddedChapters;
    if (embedded != null && embedded.isNotEmpty) {
      totalDuration = Duration(
        microseconds: (widget.parent.runTimeTicks ?? 0) ~/ 10,
      );
    } else {
      totalDuration = Duration(
        microseconds: widget.chapters.fold<int>(
          0,
          (sum, chapter) =>
              sum +
              (chapter.runTimeTicks == null ? 0 : chapter.runTimeTicks! ~/ 10),
        ),
      );
    }

    final downloadStub = DownloadStub.fromItem(
      type: DownloadItemType.collection,
      item: widget.parent,
    );

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(widget.parent.name ??
                AppLocalizations.of(context)!.unknownName),
            expandedHeight: kToolbarHeight + 125 + 64,
            pinned: true,
            flexibleSpace: AudiobookFlexibleSpaceBar(
              audiobook: widget.parent,
              chapters: widget.chapters,
              totalDuration: totalDuration,
            ),
            actions: [
              FavoriteButton(item: widget.parent),
              if (!ref.watch(finampSettingsProvider.isOffline))
                DownloadButton(
                  item: downloadStub,
                  children: widget.chapters,
                ),
            ],
          ),
          if (widget.chapters.isNotEmpty)
            _buildChapterList(context)
          else
            SliverFillRemaining(
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.audiobookChapters,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A list tile for a single embedded chapter marker inside a .m4b audiobook.
/// Tapping starts playback of [parent] seeking to the chapter's start position.
class _ChapterInfoTile extends StatelessWidget {
  const _ChapterInfoTile({
    required this.chapter,
    required this.index,
    required this.parent,
    required this.nextChapterTicks,
  });

  final ChapterInfo chapter;
  final int index;
  final BaseItemDto parent;

  /// startPositionTicks of the following chapter (or the book's RunTimeTicks
  /// for the last chapter), used to compute this chapter's duration.
  final int nextChapterTicks;

  @override
  Widget build(BuildContext context) {
    final startTicks = chapter.startPositionTicks;
    final durationTicks = nextChapterTicks - startTicks;
    final chapterDuration = Duration(microseconds: durationTicks ~/ 10);
    final startPosition = Duration(microseconds: startTicks ~/ 10);

    final subtitle = printDuration(chapterDuration);

    return ListTile(
      leading: CircleAvatar(
        child: Text('${index + 1}'),
      ),
      title: Text(chapter.name ?? 'Chapter ${index + 1}'),
      subtitle: Text(subtitle),
      onTap: () {
        final queueService = GetIt.instance<QueueService>();
        queueService.startPlayback(
          items: [parent],
          source: QueueItemSource.fromBaseItem(parent),
          order: FinampPlaybackOrder.linear,
          startingIndex: 0,
          initialSeekPosition: startPosition,
        );
      },
    );
  }
}
