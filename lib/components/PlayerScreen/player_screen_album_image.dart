import 'dart:async';

import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/components/animated_album_cover.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/animated_music_service.dart';
import 'package:finamp/services/current_track_metadata_provider.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import '../../services/current_album_image_provider.dart';
import '../../services/favorite_provider.dart';
import '../../menus/track_menu.dart';
import '../album_image.dart';

class PlayerScreenAlbumImage extends ConsumerStatefulWidget {
  const PlayerScreenAlbumImage({super.key});

  @override
  ConsumerState<PlayerScreenAlbumImage> createState() => _PlayerScreenAlbumImageState();
}

class _PlayerScreenAlbumImageState extends ConsumerState<PlayerScreenAlbumImage> {
  String? _currentAnimatedCoverSource;
  String? _lastTrackId;

  @override
  Widget build(BuildContext context) {
    final queueService = GetIt.instance<QueueService>();
    final audioService = GetIt.instance<MusicPlayerBackgroundTask>();
    final animatedMusicService = GetIt.instance<AnimatedMusicService>();

    return StreamBuilder<FinampQueueInfo?>(
      stream: queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // show loading indicator
          return const Center(child: CircularProgressIndicator());
        }

        final queueInfo = snapshot.data!;
        final currentTrack = queueInfo.currentTrack;
        final currentTrackId = currentTrack?.baseItemId.raw;

        // Only proceed if we have a current track
        if (currentTrackId == null) {
          if (_currentAnimatedCoverSource != null) {
            _currentAnimatedCoverSource = null;
            if (mounted) setState(() {});
          }
          return _buildStaticCover(snapshot, audioService);
        }

        // Watch the metadata provider for the current track
        final metadataAsyncValue = ref.watch(currentTrackMetadataProvider);

        // Handle metadata loading/error states
        final metadata = metadataAsyncValue.unwrapPrevious();
        final metadataValue = metadata.valueOrNull;

        // Check if track changed
        if (currentTrackId != _lastTrackId) {
          _lastTrackId = currentTrackId;

          String? animatedCoverSource;

          // First, try to use locally cached file
          if (metadataValue?.animatedCoverFile != null && metadataValue!.animatedCoverFile!.existsSync()) {
            animatedCoverSource = metadataValue.animatedCoverFile!.path;
          }
          // Fallback to online streaming if not in offline mode and no local file
          else if (!FinampSettingsHelper.finampSettings.isOffline) {
            // Use the animated music service to check if animated cover exists
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final hasAnimatedCover = await animatedMusicService.hasAnimatedCover(BaseItemId(currentTrackId));
                if (mounted && hasAnimatedCover && _lastTrackId == currentTrackId) {
                  final onlineUrl = await animatedMusicService.getAnimatedCoverForTrack(BaseItemId(currentTrackId));
                  if (mounted && onlineUrl != null && _lastTrackId == currentTrackId) {
                    setState(() {
                      _currentAnimatedCoverSource = onlineUrl;
                    });
                  }
                } else if (mounted && !hasAnimatedCover) {
                  // No animated cover available
                  setState(() {
                    _currentAnimatedCoverSource = null;
                  });
                }
              } catch (e) {
                // Silently fail - no animated cover available for streaming
                if (mounted) {
                  setState(() {
                    _currentAnimatedCoverSource = null;
                  });
                }
              }
            });
          } else {
            // No animated cover available
            animatedCoverSource = null;
          }

          // Update animated cover source if we have a local file
          if (animatedCoverSource != _currentAnimatedCoverSource) {
            _currentAnimatedCoverSource = animatedCoverSource;
            if (mounted) setState(() {});
          }
        }

        return _buildCoverWithGestures(snapshot, audioService);
      },
    );
  }

  Widget _buildStaticCover(AsyncSnapshot<FinampQueueInfo?> snapshot, MusicPlayerBackgroundTask audioService) {
    return _buildCoverWithGestures(snapshot, audioService);
  }

  Widget _buildCoverWithGestures(AsyncSnapshot<FinampQueueInfo?> snapshot, MusicPlayerBackgroundTask audioService) {
    final currentTrack = snapshot.data?.currentTrack;

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
              item: queueItem!.baseItem!,
              showPlaybackControls: true,
              // show controls on player screen
              parentItem: inPlaylist ? queueItem.source.item : null,
              isInPlaylist: inPlaylist,
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
            final queueService = GetIt.instance<QueueService>();
            final currentTrack = queueService.getCurrentTrack();
            if (currentTrack?.baseItem != null && !FinampSettingsHelper.finampSettings.isOffline) {
              ref.read(isFavoriteProvider(currentTrack!.baseItem).notifier).toggleFavorite();
            }
          },
          onHorizontalSwipe: (direction) {
            final queueService = GetIt.instance<QueueService>();
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
              final minPadding = ref.watch(finampSettingsProvider.playerScreenCoverMinimumPadding);
              final horizontalPadding = constraints.maxWidth * (minPadding / 100.0);
              final verticalPadding = constraints.maxHeight * (minPadding / 100.0);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                child: _buildCoverWidget(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCoverWidget() {
    final borderRadius = BorderRadius.circular(8.0);
    final decoration = BoxDecoration(
      boxShadow: [BoxShadow(blurRadius: 24, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.3))],
    );

    // Show animated cover if available
    if (_currentAnimatedCoverSource != null) {
      return Stack(
        children: [
          // Fallback static image
          AlbumImage(
            imageListenable: currentAlbumImageProvider,
            borderRadius: borderRadius,
            autoScale: false,
            decoration: decoration,
          ),
          // Animated cover overlay
          AnimatedAlbumCover(animatedCoverUri: _currentAnimatedCoverSource!, borderRadius: borderRadius),
        ],
      );
    }

    // Fallback to static image
    return AlbumImage(
      imageListenable: currentAlbumImageProvider,
      borderRadius: borderRadius,
      autoScale: false,
      decoration: decoration,
    );
  }
}
