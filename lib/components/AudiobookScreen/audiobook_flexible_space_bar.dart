import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../album_image.dart';
import '../print_duration.dart';

/// The flexible space bar header shown on the audiobook screen. Displays the
/// book cover image alongside key metadata (narrator, runtime) and play
/// controls (Resume / Play from Beginning).
class AudiobookFlexibleSpaceBar extends StatelessWidget {
  const AudiobookFlexibleSpaceBar({
    super.key,
    required this.audiobook,
    required this.chapters,
    required this.totalDuration,
  });

  final BaseItemDto audiobook;
  final List<BaseItemDto> chapters;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final queueService = GetIt.instance<QueueService>();

    return FlexibleSpaceBar(
      background: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 125,
                      child: AlbumImage(item: audiobook),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AudiobookInfo(
                        audiobook: audiobook,
                        totalDuration: totalDuration,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ResumeButton(
                          chapters: chapters,
                          audiobook: audiobook,
                          queueService: queueService,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: chapters.isEmpty
                              ? null
                              : () => queueService.startPlayback(
                                    items: chapters,
                                    source: QueueItemSource.fromBaseItem(audiobook),
                                    order: FinampPlaybackOrder.linear,
                                    startingIndex: 0,
                                  ),
                          icon: const Icon(Icons.replay),
                          label: Text(AppLocalizations.of(context)!.playFromBeginning),
                        ),
                      ),
                    ],
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

class _AudiobookInfo extends StatelessWidget {
  const _AudiobookInfo({
    required this.audiobook,
    required this.totalDuration,
  });

  final BaseItemDto audiobook;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final narrator = audiobook.artists?.join(", ") ?? audiobook.albumArtist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (narrator != null && narrator.isNotEmpty)
          _MetadataRow(
            icon: Icons.person,
            label: "${AppLocalizations.of(context)!.audiobookNarrator}: $narrator",
          ),
        _MetadataRow(
          icon: Icons.timer,
          label: printDuration(totalDuration),
        ),
        if (audiobook.productionYear != null)
          _MetadataRow(
            icon: Icons.event,
            label: audiobook.productionYearString,
          ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A "Resume" button that starts playback from the chapter the user was last
/// listening to (using Jellyfin's playback position data), or from chapter 0
/// if no position is tracked. Fetches fresh position data from the server
/// before starting playback to guard against stale cached values.
class _ResumeButton extends StatelessWidget {
  const _ResumeButton({
    required this.chapters,
    required this.audiobook,
    required this.queueService,
  });

  final List<BaseItemDto> chapters;
  final BaseItemDto audiobook;
  final QueueService queueService;

  /// Returns the index of the first partially-played chapter, or the first
  /// unplayed chapter after a run of fully-played ones.
  int _resumeIndex() {
    for (int i = 0; i < chapters.length; i++) {
      final userData = chapters[i].userData;
      if (userData == null) continue;
      final played = userData.playedPercentage ?? 0;
      if (played > 0 && played < 99) return i;
    }
    for (int i = 0; i < chapters.length; i++) {
      final userData = chapters[i].userData;
      if (userData == null || !userData.played) return i;
    }
    return 0;
  }

  Duration? _resumePosition() {
    final idx = _resumeIndex();
    final ticks = chapters[idx].userData?.playbackPositionTicks ?? 0;
    if (ticks <= 0) return null;
    return Duration(microseconds: ticks ~/ 10);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: chapters.isEmpty
          ? null
          : () async {
              final idx = _resumeIndex();
              Duration? position;
              try {
                final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
                final freshItem = await jellyfinApiHelper
                    .getItemById(chapters[idx].id);
                final ticks = freshItem.userData?.playbackPositionTicks ?? 0;
                if (ticks > 0) {
                  position = Duration(microseconds: ticks ~/ 10);
                }
              } catch (_) {
                position = _resumePosition();
              }
              await queueService.startPlayback(
                items: chapters,
                source: QueueItemSource.fromBaseItem(audiobook),
                order: FinampPlaybackOrder.linear,
                startingIndex: idx,
                initialSeekPosition: position,
              );
            },
      icon: const Icon(Icons.play_arrow),
      label: Text(AppLocalizations.of(context)!.resumeAudiobook),
    );
  }
}
