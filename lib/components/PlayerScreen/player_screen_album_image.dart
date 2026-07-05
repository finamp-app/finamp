import 'dart:async';

import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import '../../menus/track_menu.dart';
import '../../services/current_album_image_provider.dart';
import '../../services/favorite_provider.dart';
import '../album_image.dart';

class PlayerScreenAlbumImage extends ConsumerWidget {
  const PlayerScreenAlbumImage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    final audioService = GetIt.instance<MusicPlayerBackgroundTask>();
    return StreamBuilder<FinampQueueInfo?>(
      stream: queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // show loading indicator
          return const Center(child: CircularProgressIndicator());
        }
        final currentTrack = snapshot.data!.currentTrack;

        return Semantics(
          label: AppLocalizations.of(
            context,
          )!.playerAlbumArtworkTooltip(currentTrack?.item.title ?? AppLocalizations.of(context)!.unknownName),
          excludeSemantics: true, // replace child semantics with custom semantics
          container: true,
          child: GestureDetector(
            onSecondaryTapDown: (_) async {
              var queueItem = snapshot.data!.currentTrack;
              if (queueItem?.baseItem != null) {
                var inPlaylist = queueItemInPlaylist(queueItem);
                await showModalTrackMenu(
                  context: context,
                  item: queueItem!.baseItem,
                  showPlaybackControls: true,
                  // show controls on player screen
                  parentItem: inPlaylist ? queueItem.source.item : null,
                );
              }
            },
            child: SimpleGestureDetector(
              //TODO replace with PageView, this is just a placeholder
              onTap: () {
                unawaited(audioService.togglePlayback());
                FeedbackHelper.feedback(FeedbackType.selection);
              },
              onDoubleTap: () {
                final currentTrack = queueService.getCurrentTrack();
                if (currentTrack?.baseItem != null && !FinampSettingsHelper.finampSettings.isOffline) {
                  ref.read(isFavoriteProvider(currentTrack!.baseItem).notifier).toggleFavorite();
                }
              },
              onHorizontalSwipe: (direction) {
                if (direction == SwipeDirection.left) {
                  if (!FinampSettingsHelper.finampSettings.disableGesture) {
                    queueService.skipByOffset(1);
                    FeedbackHelper.feedback(FeedbackType.selection);
                  }
                } else if (direction == SwipeDirection.right) {
                  if (!FinampSettingsHelper.finampSettings.disableGesture) {
                    queueService.skipByOffset(-1);
                    FeedbackHelper.feedback(FeedbackType.selection);
                  }
                }
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  //print(
                  //    "control height is ${MediaQuery.sizeOf(context).height - 53.0 - constraints.maxHeight - 24}");
                  final minPadding = ref.watch(finampSettingsProvider.playerScreenCoverMinimumPadding);
                  final horizontalPadding = constraints.maxWidth * (minPadding / 100.0);
                  final verticalPadding = constraints.maxHeight * (minPadding / 100.0);
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                    child: AlbumImage(
                      imageListenable: currentAlbumImageProvider,
                      borderRadius: BorderRadius.circular(8.0),
                      // Load player cover at max size to allow more seamless scaling
                      autoScale: false,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(blurRadius: 24, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.3)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
