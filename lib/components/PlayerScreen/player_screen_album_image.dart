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

import '../../services/favorite_provider.dart';
import '../../menus/track_menu.dart';
import '../album_image.dart';

/// The swipeable album artwork panel displayed on the player screen.
///
/// Renders a [PageView] of album images, one per track in the current queue,
/// so the user can swipe left/right to skip forward/backward. The displayed
/// page is kept in sync with [QueueService]: when the queue's current-track
/// index changes externally (e.g. auto-advance, skip button) the controller
/// animates or jumps to the correct page, and when the user swipes the page
/// the offset is forwarded to [QueueService.skipByOffset].
class PlayerScreenAlbumImage extends ConsumerStatefulWidget {
  const PlayerScreenAlbumImage({super.key});

  @override
  ConsumerState<PlayerScreenAlbumImage> createState() => _PlayerScreenAlbumImageState();
}

class _PlayerScreenAlbumImageState extends ConsumerState<PlayerScreenAlbumImage> {
  /// Controller for the [PageView] that drives the swipe-to-skip animation.
  /// Lazily initialised on the first build that has queue data.
  PageController? _pageController;

  /// The queue index that was active on the previous build, used to detect
  /// when the current track has changed so the controller can be animated.
  int? _lastIndex;

  /// A snapshot of [FinampQueueInfo.fullQueue] captured on the last build.
  /// Kept as state so the PageView can still render after the queue stream
  /// emits a null current-track (e.g. briefly during track transitions).
  List<FinampQueueItem> _displayQueue = [];

  /// The index within [_displayQueue] that corresponds to the current track.
  int _displayIndex = 0;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueService = GetIt.instance<QueueService>();
    final audioService = GetIt.instance<MusicPlayerBackgroundTask>();

    return StreamBuilder<FinampQueueInfo?>(
      stream: queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // show loading indicator
          return const Center(child: CircularProgressIndicator());
        }

        final queueInfo = snapshot.data!;

        // Refresh the local queue snapshot whenever a current track is known,
        // or when the widget is first shown and _displayQueue is still empty.
        // This guards against briefly-null currentTrack during transitions.
        if (queueInfo.currentTrack != null || _displayQueue.isEmpty) {
          _displayQueue = queueInfo.fullQueue;
          _displayIndex = queueInfo.previousTracks.length;

          // Clamp the index in case previousTracks is longer than fullQueue
          // (can occur transiently at the end of a queue).
          if (_displayIndex >= _displayQueue.length && _displayQueue.isNotEmpty) {
            _displayIndex = _displayQueue.length - 1;
          }
        } else if (queueInfo.fullQueue.isEmpty) {
          _displayQueue = [];
          _displayIndex = 0;
        }

        if (_displayQueue.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_pageController == null) {
          // First build with data — create the controller positioned at the
          // current track without any animation.
          _pageController = PageController(initialPage: _displayIndex);
          _lastIndex = _displayIndex;
        } else if (_lastIndex != _displayIndex) {
          // The current-track index has changed since the last build (e.g. the
          // user skipped via a button or the track auto-advanced). Animate the
          // PageView to the new page after the current frame is painted so the
          // controller is guaranteed to have clients attached.
          _lastIndex = _displayIndex;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController?.hasClients ?? false) {
              final currentPage = _pageController!.page?.round() ?? 0;
              if (currentPage != _displayIndex) {
                if ((currentPage - _displayIndex).abs() > 1) {
                  // More than one page away — jump instantly to avoid a long
                  // multi-page animation that would feel sluggish.
                  _pageController!.jumpToPage(_displayIndex);
                } else {
                  // Adjacent page — animate smoothly.
                  _pageController!.animateToPage(
                    _displayIndex,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              }
            }
          });
        }

        return Semantics(
          // Announce the current track title to screen readers; the nested
          // image widget's own semantics are suppressed via excludeSemantics.
          label: AppLocalizations.of(context)!.playerAlbumArtworkTooltip(
              queueInfo.currentTrack?.item.title ?? AppLocalizations.of(context)!.unknownName),
          excludeSemantics: true, // replace child semantics with custom semantics
          container: true,

          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),

            itemCount: _displayQueue.length,
            onPageChanged: (newIndex) {
              // Swipe gestures can be globally disabled in settings.
              if (FinampSettingsHelper.finampSettings.disableGesture) return;

              // Calculate how many positions the user swiped relative to the
              // track that was current when this build ran, then forward that
              // offset to the queue service.
              final offset = newIndex - _displayIndex;

              if (offset != 0) {
                queueService.skipByOffset(offset);
                FeedbackHelper.feedback(FeedbackType.selection);
              }
            },
            itemBuilder: (context, index) {
              final queueItem = _displayQueue[index];

              return GestureDetector(
                // Secondary tap (right-click on desktop / two-finger tap on
                // some devices) opens the full track context menu.
                onSecondaryTapDown: (_) async {
                  var inPlaylist = queueItemInPlaylist(queueItem);
                  await showModalTrackMenu(
                    context: context,
                    item: queueItem.baseItem!,
                    showPlaybackControls: true,
                    parentItem: inPlaylist ? queueItem.source.item : null,
                    isInPlaylist: inPlaylist,
                  );
                },
                child: SimpleGestureDetector(
                  // Single tap toggles play/pause.
                  onTap: () {
                    unawaited(audioService.togglePlayback());
                    FeedbackHelper.feedback(FeedbackType.selection);
                  },
                  // Double tap toggles the favorite state (online only — the
                  // Jellyfin API is not reachable in offline mode).
                  onDoubleTap: () {
                    if (!FinampSettingsHelper.finampSettings.isOffline) {
                      ref.read(isFavoriteProvider(queueItem.baseItem!).notifier).toggleFavorite();
                    }
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Read the user-configured minimum padding percentage and
                      // convert it to logical pixels relative to the available
                      // space, so the artwork insets scale with the widget size.
                      final minPadding = ref.watch(finampSettingsProvider.playerScreenCoverMinimumPadding);
                      final horizontalPadding = constraints.maxWidth * (minPadding / 100.0);
                      final verticalPadding = constraints.maxHeight * (minPadding / 100.0);

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                        child: AlbumImage(
                          item: queueItem.baseItem,
                          borderRadius: BorderRadius.circular(8.0),
                          autoScale: false,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 24,
                                offset: const Offset(0, 4),
                                // ~30 % opacity black shadow for depth.
                                color: Colors.black.withAlpha(77),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
