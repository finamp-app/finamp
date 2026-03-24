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

/// Stiffer page-snap spring so the cover settles faster after a swipe.
/// ratio: 1.0 = critically damped — no overshoot.
class _FastSnapPhysics extends PageScrollPhysics {
  const _FastSnapPhysics({super.parent});

  @override
  _FastSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _FastSnapPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.4,
    stiffness: 500.0,
    ratio: 1.0,
  );
}

/// Swipeable album artwork shown on the player screen.
///
/// Renders a [PageView] with one page per track in the queue so the user can
/// swipe left/right to skip. The view stays in sync with [QueueService]:
/// external index changes (auto-advance, skip buttons) animate the page, and
/// user swipes are forwarded to [QueueService.skipByOffset].
///
/// ## Skip flow
/// Skips are debounced so rapid swipes are batched into a single
/// [QueueService.skipByOffset] call after 200 ms of inactivity. The visual
/// PageView moves immediately; only the backend call is deferred.
///
/// ## Rubber-band prevention
/// After a swipe the stream may briefly reflect a stale queue index while
/// Jellyfin processes the skip. Stream-driven page sync is suppressed while
/// the pointer is down, while the debounce is pending, and for 400 ms after
/// the skip is sent — long enough to cover the server round-trip.
class PlayerScreenAlbumImage extends ConsumerStatefulWidget {
  const PlayerScreenAlbumImage({super.key});

  @override
  ConsumerState<PlayerScreenAlbumImage> createState() => _PlayerScreenAlbumImageState();
}

class _PlayerScreenAlbumImageState extends ConsumerState<PlayerScreenAlbumImage> {
  PageController? _pageController;
  List<FinampQueueItem> _displayQueue = [];

  /// The page index currently shown in the PageView. Kept in sync with the
  /// queue stream unless sync is suppressed (see [_suppressStreamSync]).
  int _displayIndex = 0;

  /// Timestamp of the last [_scheduleSkip] call, used to enforce the
  /// post-skip server-processing window in [_suppressStreamSync].
  DateTime _lastSkipTime = DateTime.now();

  /// True while a pointer is in contact with the screen.
  bool _pointerDown = false;

  /// The [_displayIndex] at the moment the current touch began, used to
  /// compute the total swipe offset on pointer-up.
  int _dragStartIndex = 0;

  /// Accumulated page offset not yet sent to [QueueService]. Multiple rapid
  /// swipes add up here and are flushed as a single call by [_skipDebounceTimer].
  int _pendingSkipTotal = 0;

  /// Fires 200 ms after the last swipe to flush [_pendingSkipTotal].
  Timer? _skipDebounceTimer;

  /// Whether stream-driven page sync should be suppressed right now.
  ///
  /// Suppression is active while:
  /// - the pointer is down (mid-drag),
  /// - the debounce timer is running (skip not yet sent to the server),
  /// - within 400 ms of the last sent skip (server processing window).
  bool get _suppressStreamSync =>
      _pointerDown ||
      (_skipDebounceTimer?.isActive ?? false) ||
      DateTime.now().difference(_lastSkipTime).inMilliseconds < 400;

  /// Accumulates [offset] into [_pendingSkipTotal] and (re-)starts the
  /// debounce timer. The actual [QueueService.skipByOffset] call is deferred
  /// so that rapid consecutive swipes are coalesced into one backend call.
  void _scheduleSkip(int offset, QueueService queueService) {
    _lastSkipTime = DateTime.now();
    _pendingSkipTotal += offset;
    _skipDebounceTimer?.cancel();
    _skipDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (_pendingSkipTotal != 0) {
        queueService.skipByOffset(_pendingSkipTotal);
        _pendingSkipTotal = 0;
      }
    });
  }

  @override
  void dispose() {
    _skipDebounceTimer?.cancel();
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
        int streamIndex = 0;

        if (queueInfo.currentTrack != null || _displayQueue.isEmpty) {
          _displayQueue = queueInfo.fullQueue;
          streamIndex = queueInfo.previousTracks.length;
        } else if (queueInfo.fullQueue.isEmpty) {
          _displayQueue = [];
        }

        if (_displayQueue.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_pageController == null) {
          // First build: initialise the controller at the current track's page.
          _displayIndex = streamIndex;
          _pageController = PageController(initialPage: _displayIndex);
        } else if (!_suppressStreamSync) {
          // Stream has a new authoritative index (auto-advance, skip button,
          // etc.) and we're not in a swipe/debounce/processing window.
          _displayIndex = streamIndex;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController?.hasClients ?? false) {
              final currentPage = _pageController!.page?.round() ?? 0;
              if (currentPage != _displayIndex) {
                _pageController!.animateToPage(
                  _displayIndex,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                );
              }
            }
          });
        }

        return Semantics(
          label: AppLocalizations.of(context)!.playerAlbumArtworkTooltip(
              queueInfo.currentTrack?.item.title ?? AppLocalizations.of(context)!.unknownName),
          excludeSemantics: true, // replace child semantics with custom semantics
          container: true,
          child: Listener(
            onPointerDown: (_) {
              _pointerDown = true;
              _dragStartIndex = _displayIndex;
            },
            onPointerCancel: (_) => _pointerDown = false,
            onPointerUp: (_) {
              if (!_pointerDown) return;
              _pointerDown = false;
              if (FinampSettingsHelper.finampSettings.disableGesture) return;

              final offset = _displayIndex - _dragStartIndex;
              if (offset != 0) {
                FeedbackHelper.feedback(FeedbackType.selection);
                _scheduleSkip(offset, queueService);
              }
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const _FastSnapPhysics(),
              itemCount: _displayQueue.length,
              onPageChanged: (newIndex) {
                if (FinampSettingsHelper.finampSettings.disableGesture) return;
                final offset = newIndex - _displayIndex;
                if (offset == 0) return;
                _displayIndex = newIndex;

                // The pointer is already up: this page change was driven by
                // fling momentum after the finger lifted, so fire the skip now
                // instead of waiting for onPointerUp (which already fired).
                if (!_pointerDown) {
                  FeedbackHelper.feedback(FeedbackType.selection);
                  _scheduleSkip(offset, queueService);
                }
              },
              itemBuilder: (context, index) {
                final queueItem = _displayQueue[index];

                return GestureDetector(
                  // Desktop / right-click: open track context menu.
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
                    onTap: () {
                      unawaited(audioService.togglePlayback());
                      FeedbackHelper.feedback(FeedbackType.selection);
                    },
                    onDoubleTap: () {
                      if (!FinampSettingsHelper.finampSettings.isOffline) {
                        ref.read(isFavoriteProvider(queueItem.baseItem!).notifier).toggleFavorite();
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final minPadding = ref.watch(finampSettingsProvider.playerScreenCoverMinimumPadding);
                        final horizontalPadding = constraints.maxWidth * (minPadding / 100.0);
                        final verticalPadding = constraints.maxHeight * (minPadding / 100.0);

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                          child: AlbumImage(
                            item: queueItem.baseItem,
                            borderRadius: BorderRadius.circular(8.0),
                            // Load player cover at max size to allow more seamless scaling
                            autoScale: false,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 24,
                                  offset: const Offset(0, 4),
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
          ),
        );
      },
    );
  }
}
