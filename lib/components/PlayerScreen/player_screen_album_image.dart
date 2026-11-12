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
import '../../services/animated_music_service.dart';
import '../../services/current_album_image_provider.dart';
import '../../services/favorite_provider.dart';
import '../album_image.dart';
import 'animated_cover_overlay.dart';

class PlayerScreenAlbumImage extends ConsumerWidget {
  const PlayerScreenAlbumImage({super.key, this.showHiddenPlayerActions = false});

  final bool showHiddenPlayerActions;

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
        final hideArtwork = ref.watch(verticalBackgroundReadyProvider);
        final collapsed = ref.watch(verticalBackgroundControlsCollapsedProvider);

        return Semantics(
          label: hideArtwork
              ? (collapsed
                    ? AppLocalizations.of(context)!.showVerticalBackgroundControls
                    : AppLocalizations.of(context)!.hideVerticalBackgroundControls)
              : AppLocalizations.of(
                  context,
                )!.playerAlbumArtworkTooltip(currentTrack?.item.title ?? AppLocalizations.of(context)!.unknownName),
          excludeSemantics: true, // replace child semantics with custom semantics
          container: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (_) async {
              var queueItem = snapshot.data!.currentTrack;
              if (queueItem?.baseItem != null) {
                var inPlaylist = queueItemInPlaylist(queueItem);
                await showModalTrackMenu(
                  context: context,
                  item: queueItem!.baseItem,
                  showPlaybackControls: true,
                  showHiddenPlayerActions: showHiddenPlayerActions,
                  // show controls on player screen
                  parentItem: inPlaylist ? queueItem.source.item : null,
                );
              }
            },
            child: SimpleGestureDetector(
              behavior: HitTestBehavior.opaque,
              //TODO replace with PageView, this is just a placeholder
              onTap: () {
                if (hideArtwork) {
                  ref.read(verticalBackgroundControlsCollapsedProvider.notifier).toggle();
                } else {
                  unawaited(audioService.togglePlayback());
                }
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
                  final horizontalPadding = hideArtwork ? 0.0 : constraints.maxWidth * (minPadding / 100.0);
                  final verticalPadding = hideArtwork ? 0.0 : constraints.maxHeight * (minPadding / 100.0);
                  const coverRadius = BorderRadius.all(Radius.circular(8.0));
                  final fadeDuration = animatedMusicFadeDurationOf(context);
                  return AnimatedPadding(
                    duration: fadeDuration,
                    curve: animatedMusicFadeCurve,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                    child: AnimatedOpacity(
                      duration: fadeDuration,
                      curve: animatedMusicFadeCurve,
                      opacity: hideArtwork ? 0 : 1,
                      // Center loosens the constraints so AspectRatio takes effect.
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AlbumImage(
                                imageListenable: currentAlbumImageProvider,
                                borderRadius: coverRadius,
                                // Load player cover at max size to allow more seamless scaling
                                autoScale: false,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 24,
                                      offset: const Offset(0, 4),
                                      color: Colors.black.withValues(alpha: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                              const AnimatedCoverOverlay(borderRadius: coverRadius),
                            ],
                          ),
                        ),
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
