import 'dart:math';

import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/PlayerScreen/album_chip.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_more.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/progress_state_stream.dart';
import 'package:finamp/models/jellyfin_models.dart' as jellyfin_models;
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/scrolling_text_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackNameContent extends ConsumerWidget {
  const TrackNameContent(this.controller, {super.key});

  final PlayerHideableController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(QueueService.queueProvider);

    if (queue?.currentTrack == null) {
      return const CircularProgressIndicator();
    }
    final currentTrack = queue!.currentTrack!;

    final jellyfin_models.BaseItemDto trackBaseItemDto = currentTrack.baseItem;

    // (Removed duplicate getContent, keeping only the enhanced version below)
    Widget getContent(BoxConstraints constraints, double padding) {
      // Determine if this is an audiobook
      final isAudioBook = trackBaseItemDto.type == "AudioBook";

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth - padding),
            child: Semantics.fromProperties(
              properties: SemanticsProperties(
                label: "${currentTrack.item.title} (${AppLocalizations.of(context)!.title})",
              ),
              excludeSemantics: true,
              container: true,
              child: Consumer(
                builder: (context, ref, _) {
                  final text = currentTrack.item.title;
                  final isTwoLineMode = controller.shouldShow(PlayerHideable.twoLineTitle);

                  final textStyle = TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: Theme.brightnessOf(context) == Brightness.light ? FontWeight.w500 : FontWeight.w600,
                  );

                  final textSpan = TextSpan(text: text, style: textStyle);
                  final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, maxLines: 2)
                    ..layout(maxWidth: 280);
                  final wouldOverflow = textPainter.didExceedMaxLines;
                  textPainter.dispose();

                  if (!isTwoLineMode) {
                    return Text(
                      text,
                      style: textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    );
                  } else {
                    if (wouldOverflow && ref.watch(finampSettingsProvider.oneLineMarqueeTextButton)) {
                      return SizedBox(
                        width: 280,
                        height: 30,
                        child: ScrollingTextHelper(
                          id: ValueKey(currentTrack.item.id),
                          text: text,
                          style: textStyle,
                          alignment: TextAlign.center,
                        ),
                      );
                    } else {
                      return SizedBox(
                        height: 48.0,
                        child: Center(
                          child: Text(
                            text,
                            style: textStyle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ),
          // Show current chapter name as subtitle/tag line for audiobooks.
          // Uses progressStateStream so both the MediaItem (with its lazily-
          // injected chapters) and the playback position are always up to date.
          if (isAudioBook)
            StreamBuilder<ProgressState>(
              stream: progressStateStream,
              builder: (context, snapshot) {
                final mediaItem = snapshot.data?.mediaItem;
                final position = snapshot.data?.position;
                if (mediaItem == null || position == null) return const SizedBox.shrink();

                // Read chapters from the MediaItem extras — this is where
                // updateCurrentMediaItemChapters stores them.
                List<ChapterInfo>? chapters;
                try {
                  final raw = mediaItem.extras?['itemJson']?['Chapters'] as List<dynamic>?;
                  if (raw != null && raw.isNotEmpty) {
                    chapters = raw
                        .cast<Map<Object?, Object?>>()
                        .map((m) => ChapterInfo.fromJson(Map<String, dynamic>.from(m as Map)))
                        .toList();
                  }
                } catch (_) {}

                if (chapters == null || chapters.isEmpty) return const SizedBox.shrink();

                final posTicks = position.inMicroseconds * 10;
                int currentIdx = 0;
                for (int i = 0; i < chapters.length; i++) {
                  if (chapters[i].startPositionTicks <= posTicks) {
                    currentIdx = i;
                  } else {
                    break;
                  }
                }
                final chapterName = chapters[currentIdx].name ?? 'Chapter ${currentIdx + 1}';

                return Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                  child: Text(
                    chapterName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PlayerButtonsMore(item: trackBaseItemDto, queueItem: currentTrack),
              Flexible(
                child: ArtistChips(
                  baseItem: trackBaseItemDto,
                  backgroundColor: IconTheme.of(context).color!.withOpacity(0.1),
                ),
              ),
              AddToPlaylistButton(item: trackBaseItemDto, queueItem: currentTrack),
            ],
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              child: AlbumChips(
                baseItem: trackBaseItemDto!,
                backgroundColor: IconTheme.of(context).color!.withOpacity(0.1),
                key: trackBaseItemDto.album == null ? null : ValueKey("${trackBaseItemDto.album}-album"),
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double padding = ((constraints.maxWidth - 260) / 4).clamp(0, 20);
        return Padding(
          padding: EdgeInsets.only(left: padding, right: padding, bottom: 4.0),
          child: getContent(constraints, padding),
        );
      },
    );
  }
}
