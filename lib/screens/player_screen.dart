import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/PlayerScreen/control_area.dart';
import 'package:finamp/components/PlayerScreen/player_screen_album_image.dart';
import 'package:finamp/components/PlayerScreen/player_screen_appbar_title.dart';
import 'package:finamp/components/PlayerScreen/player_split_screen_scaffold.dart';
import 'package:finamp/components/PlayerScreen/queue_button.dart';
import 'package:finamp/components/PlayerScreen/queue_list.dart';
import 'package:finamp/components/PlayerScreen/track_name_content.dart';
import 'package:finamp/components/finamp_app_bar_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/output_menu.dart';
import 'package:finamp/menus/playlist_actions_menu.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/blurred_player_screen_background.dart';
import 'package:finamp/screens/lyrics_screen.dart';
import 'package:finamp/services/current_track_metadata_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import 'package:finamp/services/animated_music_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const double _defaultToolbarHeight = 53.0;
const int _defaultMaxToolbarLines = 2;

final _videoBackgroundProvider = StateProvider<bool>((ref) => false);

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static const routeName = "/nowplaying";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    // close the player screen if the queue is empty
    StreamSubscription<FinampQueueInfo?>? listener;
    listener = queueService.getQueueStream().listen((currentQueue) {
      if (!context.mounted) {
        listener?.cancel();
        return;
      }
      if (currentQueue == null || currentQueue.currentTrack == null && context.mounted) {
        Navigator.of(context).popUntil((route) {
          return ![
            PlayerScreen.routeName,
            QueueList.routeName,
            TrackMenu.routeName,
            playlistActionsMenuRouteName,
            LyricsScreen.routeName,
          ].contains(route.settings.name);
        });
      }
    });

    return PlayerScreenTheme(
      child: StreamBuilder<FinampQueueInfo?>(
        stream: queueService.getQueueStream(),
        initialData: queueService.getQueue(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.saveState == SavedQueueState.loading) {
            return buildLoadingScreen(context, null);
          } else if (snapshot.hasData && snapshot.data!.saveState == SavedQueueState.failed) {
            return buildLoadingScreen(context, queueService.retryQueueLoad);
          } else if (snapshot.hasData && snapshot.data!.currentTrack != null) {
            return _PlayerScreenContent(playerScreen: this);
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget buildLoadingScreen(BuildContext context, void Function()? retryCallback) {
    double imageSize = min(MediaQuery.widthOf(context), MediaQuery.heightOf(context)) / 2;

    return SimpleGestureDetector(
      onTap: retryCallback,
      child: Scaffold(
        backgroundColor: Color.alphaBlend(
          Theme.brightnessOf(context) == Brightness.dark
              ? IconTheme.of(context).color!.withOpacity(0.35)
              : IconTheme.of(context).color!.withOpacity(0.5),
          Theme.brightnessOf(context) == Brightness.dark ? Colors.black : Colors.white,
        ),
        // Required for sleep timer input
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          minimum: const EdgeInsets.only(top: _defaultToolbarHeight),
          child: SizedBox.expand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                (retryCallback != null)
                    ? Icon(Icons.refresh, size: imageSize)
                    : SizedBox(width: imageSize, height: imageSize, child: const CircularProgressIndicator.adaptive()),
                const Spacer(),
                BalancedText(
                  (retryCallback != null)
                      ? AppLocalizations.of(context)!.queueRetryMessage
                      : AppLocalizations.of(context)!.queueLoadingMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, height: 26 / 20),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerScreenContent extends ConsumerWidget {
  const _PlayerScreenContent({required this.playerScreen});

  final Widget playerScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = PlayerHideableController();

    var screenOrientation = MediaQuery.orientationOf(context);
    double toolbarHeight = _defaultToolbarHeight;
    int maxToolbarLines = _defaultMaxToolbarLines;

    // If in landscape, only show 2 lines in toolbar instead of 3
    if (screenOrientation == Orientation.landscape) {
      toolbarHeight = 36.0;
      maxToolbarLines = 1;
    }

    final metadata = ref.watch(currentTrackMetadataProvider).unwrapPrevious();
    final hasVideoBackground =
        (metadata.valueOrNull?.verticalBackgroundVideoFile != null) ||
        (metadata.isLoading && ref.watch(_videoBackgroundProvider)) ||
        ref.watch(_videoBackgroundProvider);

    final isLyricsLoading = metadata.isLoading || metadata.isRefreshing;
    final isLyricsAvailable =
        (metadata.valueOrNull?.hasLyrics ?? false) &&
        (metadata.valueOrNull?.lyrics != null || metadata.isLoading) &&
        !metadata.hasError;

    return SafeArea(
      bottom: false,
      top: false,
      child: SimpleGestureDetector(
        onVerticalSwipe: (direction) {
          if (direction == SwipeDirection.down) {
            if (!FinampSettingsHelper.finampSettings.disableGesture) {
              Navigator.of(context).pop();
            }
          } else if (direction == SwipeDirection.up) {
            // This should never actually be called until widget finishes build and controller is initialized
            if (!FinampSettingsHelper.finampSettings.disableGesture ||
                !controller.shouldShow(PlayerHideable.bottomActions)) {
              showQueueBottomSheet(context, ref);
            }
          }
        },
        onHorizontalSwipe: (direction) {
          if (direction == SwipeDirection.left && isLyricsAvailable) {
            if (!FinampSettingsHelper.finampSettings.disableGesture ||
                !controller.shouldShow(PlayerHideable.bottomActions)) {
              Navigator.of(context).push(
                _buildSlideRouteTransition(
                  playerScreen,
                  const LyricsScreen(),
                  routeSettings: const RouteSettings(name: LyricsScreen.routeName),
                ),
              );
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle(
              // this is needed to ensure the player screen stays in full screen mode WITHOUT having contrast issues in the status bar
              systemNavigationBarColor: Colors.transparent,
              systemStatusBarContrastEnforced: false,
              statusBarIconBrightness: Theme.brightnessOf(context) == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
            elevation: 0,
            scrolledUnderElevation: 0.0, // disable tint/shadow when content is scrolled under the app bar
            centerTitle: true,
            toolbarHeight: toolbarHeight,
            title: PlayerScreenAppBarTitle(maxLines: maxToolbarLines),
            leading: usingPlayerSplitScreen ? null : FinampAppBarButton(onPressed: () => Navigator.of(context).pop()),
            actions: [],
          ),
          // Required for sleep timer input
          resizeToAvoidBottomInset: false,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              if (ref.watch(finampSettingsProvider.useCoverAsBackground)) const BlurredPlayerScreenBackground(),
              const _AnimatedVerticalBackground(),
              SafeArea(
                minimum: EdgeInsets.only(top: toolbarHeight),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    controller.setSize(Size(constraints.maxWidth, constraints.maxHeight), screenOrientation, ref);
                    if (controller.useLandscape) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: controller.albumSize.width,
                            height: controller.albumSize.height,
                            child: Padding(
                              // TODO Why does landscape get an additional 3% on top of minAlbumPadding?
                              padding: EdgeInsets.only(
                                left: constraints.maxHeight * 0.03,
                                top: constraints.maxHeight * 0.03,
                                bottom: constraints.maxHeight * 0.03,
                                right: max(0, constraints.maxHeight * 0.03 - 20),
                              ),
                              child: _AnimatedAlbumImage(hasVideoBackground: hasVideoBackground),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: controller.controlsSize.width,
                            height: controller.controlsSize.height,
                            child: Column(
                              children: [
                                const Spacer(flex: 4),
                                TrackNameContent(controller),
                                const Spacer(flex: 4),
                                ControlArea(controller),
                                if (controller.shouldShow(PlayerHideable.bottomActions)) const Spacer(flex: 10),
                                if (controller.shouldShow(PlayerHideable.bottomActions))
                                  _buildBottomActions(
                                    context,
                                    controller,
                                    isLyricsLoading: isLyricsLoading,
                                    isLyricsAvailable: isLyricsAvailable,
                                  ),
                                const Spacer(flex: 4),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      );
                    } else {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: controller.albumSize.height,
                            width: controller.albumSize.width,
                            child: _AnimatedAlbumImage(hasVideoBackground: hasVideoBackground),
                          ),
                          SizedBox(
                            height: controller.controlsSize.height,
                            width: controller.controlsSize.width,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                TrackNameContent(controller),
                                ControlArea(controller),
                                if (controller.shouldShow(PlayerHideable.bottomActions))
                                  _buildBottomActions(
                                    context,
                                    controller,
                                    isLyricsLoading: isLyricsLoading,
                                    isLyricsAvailable: isLyricsAvailable,
                                  ),
                                if (!controller.shouldShow(PlayerHideable.bottomActions)) const SizedBox(height: 5),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // This causes the source widget to blink if it does not have a key set.
  PageRouteBuilder<SlideTransition> _buildSlideRouteTransition(
    Widget sourceWidget,
    Widget targetWidget, {
    RouteSettings? routeSettings,
  }) {
    return PageRouteBuilder(
      settings: routeSettings,
      pageBuilder: (context, animation, secondaryAnimation) => targetWidget,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) {
          return child;
        }
        const curve = Curves.ease;
        const beginEnter = Offset(1.0, 0.0);
        const endEnter = Offset.zero;
        const beginExit = Offset(0.0, 0.0);
        const endExit = Offset(-1.0, 0.0);

        final tweenEnter = Tween(begin: beginEnter, end: endEnter);
        final tweenExit = Tween(begin: beginExit, end: endExit);
        final curvedAnimation = CurvedAnimation(parent: animation, curve: curve.flipped);

        return Stack(
          children: [
            SlideTransition(position: tweenExit.animate(curvedAnimation), child: sourceWidget),
            SlideTransition(position: tweenEnter.animate(curvedAnimation), child: child),
          ],
        );
      },
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    PlayerHideableController controller, {
    bool isLyricsLoading = true,
    bool isLyricsAvailable = false,
  }) {
    IconData getLyricsIcon() {
      if (!isLyricsLoading && !isLyricsAvailable) {
        return TablerIcons.microphone_2_off;
      } else {
        return TablerIcons.microphone_2;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Expanded(
          flex: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: SimpleButton(
                  text: AppLocalizations.of(context)!.outputMenuButtonTitle,
                  icon: TablerIcons.device_speaker,
                  onPressed: () async {
                    await showOutputMenu(context: context);
                  },
                  onPressedSecondary: () async {
                    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
                    await audioHandler.openBluetoothSettings();
                  },
                ),
              ),
              const Flexible(fit: FlexFit.tight, child: QueueButton()),
              Flexible(
                fit: FlexFit.tight,
                child: SimpleButton(
                  inactive: !isLyricsAvailable,
                  text: AppLocalizations.of(context)!.lyricsScreenButtonTitle,
                  icon: getLyricsIcon(),
                  onPressed: () {
                    Navigator.of(context).push(
                      _buildSlideRouteTransition(
                        playerScreen,
                        const LyricsScreen(),
                        routeSettings: const RouteSettings(name: LyricsScreen.routeName),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }
}

class _AnimatedAlbumImage extends StatelessWidget {
  const _AnimatedAlbumImage({required this.hasVideoBackground});

  final bool hasVideoBackground;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: hasVideoBackground
          ? const SizedBox.shrink(key: ValueKey('no-image'))
          : const PlayerScreenAlbumImage(key: ValueKey('album-image')),
    );
  }
}

//TODO: more to seprate file
class _AnimatedVerticalBackground extends ConsumerStatefulWidget {
  const _AnimatedVerticalBackground();

  @override
  ConsumerState<_AnimatedVerticalBackground> createState() => _AnimatedVerticalBackgroundState();
}

class _AnimatedVerticalBackgroundState extends ConsumerState<_AnimatedVerticalBackground> {
  String? _currentVideoSource;
  String? _lastTrackId;
  Player? _videoPlayer;
  VideoController? _videoController;
  StateController<bool>? _videoBackgroundNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _videoBackgroundNotifier = ref.read(_videoBackgroundProvider.notifier);
      }
    });
  }

  @override
  void dispose() {
    _videoBackgroundNotifier?.state = false;
    _disposeVideoPlayer();
    super.dispose();
  }

  void _disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _currentVideoSource = null;
  }

  void _setupVideoPlayer(String videoSource) {
    _disposeVideoPlayer();

    try {
      _videoPlayer = Player();
      _videoController = VideoController(_videoPlayer!);
      _currentVideoSource = videoSource;

      // Configure video player
      _videoPlayer!.setPlaylistMode(PlaylistMode.loop);
      _videoPlayer!.setVolume(0.0); // Mute the video
      _videoPlayer!.open(Media(videoSource));
      _videoPlayer!.play();

      // Update provider immediately, then trigger rebuild
      if (mounted) {
        ref.read(_videoBackgroundProvider.notifier).state = true;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _disposeVideoPlayer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueService = GetIt.instance<QueueService>();
    final animatedMusicService = GetIt.instance<AnimatedMusicService>();

    return StreamBuilder<FinampQueueInfo?>(
      stream: queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final queueInfo = snapshot.data!;
        final currentTrack = queueInfo.currentTrack;
        final currentTrackId = currentTrack?.baseItemId.raw;

        // Only proceed if we have a current track
        if (currentTrackId == null) {
          if (_currentVideoSource != null) {
            _disposeVideoPlayer();
          }
          return const SizedBox.shrink();
        }

        // Watch the metadata provider for the current track
        final metadataAsyncValue = ref.watch(currentTrackMetadataProvider);

        // Handle metadata loading/error states
        final metadata = metadataAsyncValue.unwrapPrevious();

        // Fix 3: Better handling of loading states
        if (metadata.isLoading && metadata.valueOrNull == null) {
          // Still loading initial metadata - keep current state
          return _buildCurrentVideo();
        }

        final metadataValue = metadata.valueOrNull;
        if (metadataValue == null) {
          // No metadata available
          if (_currentVideoSource != null) {
            _disposeVideoPlayer();
          }
          return const SizedBox.shrink();
        }

        // Check if track changed
        if (currentTrackId != _lastTrackId) {
          _lastTrackId = currentTrackId;

          String? videoSource;

          // First, try to use locally cached file from metadata
          if (metadataValue.verticalBackgroundVideoFile != null &&
              metadataValue.verticalBackgroundVideoFile!.existsSync()) {
            videoSource = metadataValue.verticalBackgroundVideoFile!.path;
          }
          // Fallback to online streaming if not in offline mode and no local file
          else if (!FinampSettingsHelper.finampSettings.isOffline) {
            // Use the animated music service to check if vertical background video exists
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final hasVerticalBackground = await animatedMusicService.hasVerticalBackgroundVideo(
                  BaseItemId(currentTrackId),
                );
                if (mounted && hasVerticalBackground && _lastTrackId == currentTrackId) {
                  final onlineUrl = await animatedMusicService.getVerticalBackgroundForTrack(
                    BaseItemId(currentTrackId),
                  );
                  if (mounted && onlineUrl != null && _lastTrackId == currentTrackId) {
                    _setupVideoPlayer(onlineUrl);
                  }
                } else if (mounted && !hasVerticalBackground) {
                  // No vertical background available, dispose current player
                  _disposeVideoPlayer();
                }
              } catch (e) {
                // Silently fail - no vertical background available for streaming
                if (mounted) {
                  _disposeVideoPlayer();
                }
              }
            });
            return _buildCurrentVideo();
          }

          // Setup video player if we have a source
          if (videoSource != null && videoSource != _currentVideoSource) {
            _setupVideoPlayer(videoSource);
          } else if (videoSource == null && _currentVideoSource != null) {
            // No video available, dispose current player
            _disposeVideoPlayer();
          }
        }

        return _buildCurrentVideo();
      },
    );
  }

  Widget _buildCurrentVideo() {
    // Show animated video background if available
    if (_videoController != null && _currentVideoSource != null) {
      return Positioned.fill(
        child: Video(controller: _videoController!, controls: null, fit: BoxFit.cover, fill: Colors.transparent),
      );
    }

    return const SizedBox.shrink();
  }
}

enum PlayerHideable {
  bigPlayButton(14, 14, 1),
  bottomActions(0, 27, 2),
  progressSlider(0, 20, 4),
  twoLineTitle(0, 48, 3),
  features(0, 20, 3),
  loopShuffleButtons(96, 0, 0),
  unhideableElements(144, 165, 0),
  controlsPaddingSmall(0, 8, 2),
  controlsPaddingBig(0, 12, 1);

  // The width/height added to the overall player screen when this item is shown.
  // Calculated by shrinking player screen control area until overflow both with
  // element shown and with element hidden, and then comparing those values.  These
  // are added together to predict the size of a player screen layout before it actually
  // gets built.
  final double width;
  final double height;

  // The maximum amount to shrink the cover image, per side, in order to show this element.
  // Needs to be multiplied by finampSettings.prioritizeCoverFactor.
  final double maxShrink;

  const PlayerHideable(this.width, this.height, this.maxShrink);
}

/// Controls what elements of the player screen are shown/hidden.
class PlayerHideableController {
  final verticalHideOrder = [
    PlayerHideable.controlsPaddingBig,
    PlayerHideable.bigPlayButton,
    PlayerHideable.bottomActions,
    PlayerHideable.controlsPaddingSmall,
    PlayerHideable.features,
    PlayerHideable.twoLineTitle,
    PlayerHideable.progressSlider,
  ];

  List<PlayerHideable> _visible = [];
  Size? _target;
  Size? _album;
  bool? _useLandscape;

  /// Update player screen hidden elements based on usable area in portrait mode.
  void _updateLayoutPortrait(Size size, WidgetRef ref) {
    var minAlbumPadding = ref.watch(finampSettingsProvider.playerScreenCoverMinimumPadding);
    var maxAlbumSize = min(size.width, size.height);

    var targetWidth = min(size.width, 1000.0);
    _updateLayoutFromWidth(targetWidth);

    // Update _visible based on a target height.  Removes elements in order of priority
    // until target is met.
    for (var element in verticalHideOrder) {
      // Allow shrinking album by up to (element.maxShrink)% of screen width per side beyond the user specified minimum value
      // if it allows us to show more controls.  Allow shrinking by greater amounts as album size grows.
      var maxDesiredPadding =
          minAlbumPadding +
          element.maxShrink *
              ref.watch(finampSettingsProvider.prioritizeCoverFactor) *
              ((maxAlbumSize - 300) / 300.0).clamp(1.0, 3.0);
      // Calculate max allowable control height to avoid shrinking album cover beyond maxPadding.
      var targetHeight = size.height - maxAlbumSize * (1 - (maxDesiredPadding / 100.0) * 2);
      if (_getSize().height < targetHeight) {
        break;
      }
      _visible.remove(element);
    }
    var desiredHeight = size.height - maxAlbumSize * (1 - (minAlbumPadding / 100.0) * 2);
    var paddedControlsHeight = max(_getSize().height, desiredHeight);
    _target = Size(targetWidth, _controlsInternalHeight(paddedControlsHeight));
    // 1/3 of padding goes under the controls and is added by the Column, the other
    // 2/3 should be included in the album cover region
    var controlsBottomPadding = (paddedControlsHeight - _target!.height) / 3.0;
    // Do not let album size go negative, use full width
    _album = Size(size.width, max(1.0, size.height - _target!.height - controlsBottomPadding));
  }

  /// Update player screen hidden elements based on usable area in landscape mode.
  void _updateLayoutLandscape(Size size, WidgetRef ref) {
    // We never want to allocate extra width to album covers while some controls
    // are hidden.
    var desiredControlsWidth = min(max(_getSize().width, size.width / 2), size.width - size.height);

    // Never expand the controls beyond 65% unless the remaining space is just album padding
    var widthPercent = ref.watch(finampSettingsProvider.prioritizeCoverFactor) * 2 + 49;
    var maxControlsWidth = max(size.width * (widthPercent / 100), size.width - size.height);
    _updateLayoutFromWidth(maxControlsWidth);

    var maxHeight = size.height;
    // Prevent allocating extra space between 50% and maxControlsWidth if we're just
    // going to shrink the play button anyway.
    if (_getSize().height >= maxHeight) {
      _visible.remove(PlayerHideable.bigPlayButton);
    }
    // Force controls width to always be at least 50% of screen.
    var minPercent = ref.watch(finampSettingsProvider.prioritizeCoverFactor) * 2 + 34;
    var minControlsWidth = max(_getSize().width, size.width * (minPercent / 100));
    // If the minimum and maximum sizes do not form a valid range, prioritize the minimum
    // and shrink the album to avoid the controls clipping.
    double targetWidth = desiredControlsWidth.clamp(minControlsWidth, max(minControlsWidth, maxControlsWidth));

    // Update _visible based on a target height.  Removes elements in order of priority
    // until target is met.
    for (var element in verticalHideOrder) {
      if (_getSize().height < maxHeight) {
        break;
      }
      _visible.remove(element);
    }

    _target = Size(min(targetWidth, 800.0), _controlsInternalHeight(maxHeight));
    // Do not let album size go negative, use full height & full left half
    _album = Size(max(1.0, size.width - targetWidth), size.height);
  }

  /// Update _visible based on a target width.  Only shrink player button if it would fit the constraints,
  /// otherwise only hide loop & shuffle buttons if that would fit the constraints, otherwise do both.
  void _updateLayoutFromWidth(double target) {
    var maxWidth = _getSize().width;
    if (maxWidth >= target) {
      if (maxWidth - PlayerHideable.bigPlayButton.width < target) {
        _visible.remove(PlayerHideable.bigPlayButton);
      } else if (maxWidth - PlayerHideable.loopShuffleButtons.width < target) {
        _visible.remove(PlayerHideable.loopShuffleButtons);
      } else {
        _visible.remove(PlayerHideable.bigPlayButton);
        _visible.remove(PlayerHideable.loopShuffleButtons);
      }
    }
  }

  void setSize(Size size, Orientation screenOrientation, WidgetRef ref) {
    _reset(ref);
    assert(_target == null && _album == null && _useLandscape == null);
    // Estimate control height as average of min and max
    var controlsSize = Size(
      PlayerHideable.unhideableElements.width,
      (PlayerHideable.unhideableElements.height + _getSize().height) / 2.0,
    );
    var landscapeWidth = max(controlsSize.width, size.width / 2.0);
    var landscapeAlbum = min(size.width - landscapeWidth, size.height);
    var portraitAlbum = min(size.width, size.height - controlsSize.height);
    if (Platform.isIOS || Platform.isAndroid) {
      _useLandscape = screenOrientation == Orientation.landscape;
    } else {
      _useLandscape = landscapeAlbum > portraitAlbum;
    }
    if (_useLandscape!) {
      _updateLayoutLandscape(size, ref);
    } else {
      _updateLayoutPortrait(size, ref);
    }
  }

  /// Reset controller to visibility
  void _reset(WidgetRef ref) {
    _target = null;
    _album = null;
    _useLandscape = null;
    _visible = List.from(PlayerHideable.values);
    if (ref.watch(finampSettingsProvider.hidePlayerBottomActions)) {
      _visible.remove(PlayerHideable.bottomActions);
    }
    if (ref.watch(finampSettingsProvider.suppressPlayerPadding)) {
      _visible.remove(PlayerHideable.controlsPaddingSmall);
      _visible.remove(PlayerHideable.controlsPaddingBig);
    }
    if (!ref.watch(finampSettingsProvider.featureChipsConfiguration).enabled) {
      _visible.remove(PlayerHideable.features);
    }
  }

  /// If we have space for vertical padding, put 33% between control elements and
  /// the rest around them, up until controls have 40% padding internally.  Then
  /// switch to only external padding.
  double _controlsInternalHeight(double totalHeight) =>
      min((totalHeight - _getSize().height) / 3.0 + _getSize().height, _getSize().height * 1.4);

  /// Gets predicted size of player controls based on current _visible items.
  Size _getSize() {
    double height = 0;
    double width = 0;
    for (var element in _visible) {
      height += element.height;
      width += element.width;
    }
    return Size(width, height);
  }

  /// Get player controls target size
  Size get controlsSize => _target!;

  /// Get player album target size
  Size get albumSize => _album!;

  /// Get whether a player control element should be shown or hidden based on screen size.
  bool shouldShow(PlayerHideable element) {
    assert(_target != null && _album != null);
    return _visible.contains(element);
  }

  bool get useLandscape => _useLandscape!;
}
