import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/audio_fade_progress_visualizer_container.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/one_line_marquee_helper.dart';
import 'package:finamp/components/print_duration.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/current_track_metadata_provider.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import '../models/jellyfin_models.dart' as jellyfin_models;
import '../screens/player_screen.dart';
import '../services/current_album_image_provider.dart';
import '../services/finamp_settings_helper.dart';
import '../services/media_state_stream.dart';
import '../services/music_player_background_task.dart';
import '../services/process_artist.dart';
import 'PlayerScreen/player_split_screen_scaffold.dart';
import 'album_image.dart';

class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key});

  static const horizontalPadding = 8.0;
  static const albumImageSize = 64.0;
  static const showPlayButtonAtEnd = false;

  BoxDecoration? getShadow(BuildContext context) => BoxDecoration(
    borderRadius: const BorderRadius.all(Radius.circular(12.0)),
    boxShadow: [
      BoxShadow(
        blurRadius: 12.0,
        spreadRadius: 8.0,
        color: Theme.brightnessOf(context) == Brightness.light
            ? darkColorScheme.surface.withOpacity(0.15)
            : darkColorScheme.surface.withOpacity(0.7),
      ),
    ],
  );

  Color getProgressForegroundColor(WidgetRef ref) {
    return ColorScheme.of(ref.context).primary;
  }

  Color getProgressBackgroundColor(WidgetRef ref) {
    return Color.alphaBlend(
      getProgressForegroundColor(ref).withOpacity(0.75),
      // this is an approximation, the actual background has the blurred cover image
      ref.watch(brightnessProvider) == Brightness.dark ? Colors.black : Colors.white,
    );
  }

  Widget buildLoadingQueueBar(WidgetRef ref, void Function()? retryCallback) {
    final progressBackgroundColor = getProgressBackgroundColor(ref).withOpacity(0.5);
    var context = ref.context;

    return SimpleGestureDetector(
      onVerticalSwipe: (direction) {
        if (direction == SwipeDirection.up && retryCallback != null) {
          retryCallback();
        }
      },
      onTap: retryCallback,
      child: Padding(
        padding: const EdgeInsets.only(left: 12.0, bottom: 12.0, right: 12.0),
        child: Container(
          decoration: getShadow(ref.context),
          child: Material(
            shadowColor: ColorScheme.of(
              context,
            ).primary.withOpacity(Theme.brightnessOf(context) == Brightness.light ? 0.75 : 0.3),
            borderRadius: BorderRadius.circular(12.0),
            clipBehavior: Clip.antiAlias,
            color: Theme.brightnessOf(context) == Brightness.dark
                ? IconTheme.of(context).color!.withOpacity(0.1)
                : Theme.of(context).cardColor,
            elevation: 8.0,
            child: Container(
              width: MediaQuery.widthOf(context),
              height: albumImageSize,
              padding: EdgeInsets.zero,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: progressBackgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: albumImageSize,
                      height: albumImageSize,
                      decoration: const ShapeDecoration(shape: Border(), color: Color.fromRGBO(0, 0, 0, 0.3)),
                      child: (retryCallback != null)
                          ? const Icon(Icons.refresh, size: albumImageSize)
                          : const Center(child: CircularProgressIndicator.adaptive()),
                    ),
                    Expanded(
                      child: Container(
                        height: albumImageSize,
                        padding: const EdgeInsets.only(left: 12, right: 4),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          (retryCallback != null)
                              ? AppLocalizations.of(context)!.queueRetryMessage
                              : AppLocalizations.of(context)!.queueLoadingMessage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> openPlayerScreen() async {
    minimizeSplitScreen.value = false;
    await GlobalSnackbar.navigatorState?.push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOutQuad));
          var offsetAnimation = animation.drive(tween);

          if (animation.status == AnimationStatus.reverse) {
            // dismiss animation
            return FadeTransition(opacity: animation, child: child);
          } else {
            return SlideTransition(position: offsetAnimation, child: child);
          }
        },
        settings: const RouteSettings(name: PlayerScreen.routeName),
      ),
    );
  }

  Widget buildNowPlayingBar(WidgetRef ref, FinampQueueItem currentTrack) {
    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    final queueService = GetIt.instance<QueueService>();

    Duration? playbackPosition;

    final currentTrackBaseItem = currentTrack.item.extras?["itemJson"] != null
        ? jellyfin_models.BaseItemDto.fromJson(currentTrack.item.extras!["itemJson"] as Map<String, dynamic>)
        : null;
    var context = ref.context;

    final elapsedPartBackgroundColor = getProgressForegroundColor(ref);
    final remainingPartBackgroundColor = getProgressBackgroundColor(ref);
    final colorScheme = ColorScheme.of(context);
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    // Over the vivid blurred artwork we use deterministic light/dark text plus a
    // soft shadow, so it stays legible no matter how bright or dark (or pure
    // black) the current cover happens to be.
    final Color primaryTextColor = isDark ? Colors.white : Colors.black;
    // In dark mode a soft black halo lifts white text off bright art. In light
    // mode the black text already has enough contrast, so we keep only a very
    // tight, faint halo — a wide blur here just makes the text look fuzzy.
    final List<Shadow> textShadows = [
      Shadow(color: Colors.black.withOpacity(isDark ? 0.45 : 0.12), blurRadius: isDark ? 6.0 : 1.5),
    ];
    // A theme-aware glass base sits *under* the blurred art so the panel always
    // reads as frosted glass in both modes — and stays a distinct, lit panel
    // even over an all-black cover, rather than melting into the page. Kept
    // fairly dense so busy content scrolling *behind* the bar doesn't bleed
    // through and fight the bar's own text.
    final Color glassBaseColor = isDark
        ? Color.alphaBlend(Colors.black.withOpacity(0.72), colorScheme.surface.withOpacity(0.5))
        : Colors.white.withOpacity(0.74);
    // The art is glazed at partial opacity so its colour shines through without
    // dictating luminance; a gentle scrim then settles the text contrast.
    final double artGlazeOpacity = isDark ? 0.62 : 0.5;
    final Color glassScrimColor = (isDark ? Colors.black : Colors.white).withOpacity(0.12);

    final showPauseButton = ref.watch(
      mediaStateProvider.select((x) => x.playbackState.playing && x.fadeDirection != FadeDirection.fadeOut),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 12.0, right: 12.0),
      child: Semantics.fromProperties(
        properties: SemanticsProperties(label: AppLocalizations.of(context)!.nowPlayingBarTooltip, button: true),
        child: SimpleGestureDetector(
          onTap: () async => await openPlayerScreen(),
          child: Dismissible(
            key: const Key("NowPlayingBarDismiss"),
            direction: ref.watch(finampSettingsProvider.disableGesture)
                ? DismissDirection.none
                : DismissDirection.vertical,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.down) {
                FeedbackHelper.feedback(FeedbackType.success);
                await queueService.stopAndClearQueue();
              } else {
                await openPlayerScreen();
              }
              return false;
            },
            dismissThresholds: const {DismissDirection.up: 0.15, DismissDirection.down: 0.7},
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: getShadow(context),
              //TODO use a PageView instead of a Dismissible, and only wrap dynamic items (not the buttons)
              child: Dismissible(
                key: const Key("NowPlayingBar"),
                direction: ref.watch(finampSettingsProvider.disableGesture)
                    ? DismissDirection.none
                    : DismissDirection.horizontal,
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    FeedbackHelper.feedback(FeedbackType.light);
                    await audioHandler.skipToNext();
                  } else {
                    FeedbackHelper.feedback(FeedbackType.light);
                    await audioHandler.skipToPrevious(forceSkip: true);
                  }
                  return false;
                },
                child: Material(
                  shadowColor: ColorScheme.of(
                    context,
                  ).primary.withOpacity(Theme.brightnessOf(context) == Brightness.light ? 0.75 : 0.3),
                  borderRadius: BorderRadius.circular(12.0),
                  clipBehavior: Clip.antiAlias,
                  // Kept transparent so the BackdropFilter below can frost the
                  // content scrolling behind the (extendBody) bar.
                  color: Colors.transparent,
                  elevation: 8.0,
                  // If we have a media item and the player hasn't finished, show
                  // the now playing bar.
                  child: //TODO move into separate component and share with queue list
                  Container(
                    width: MediaQuery.widthOf(context),
                    height: albumImageSize,
                    padding: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      // A faint glass rim defines the panel edge in both modes,
                      // so the bar reads as a lit pane even over a black cover.
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.12 : 0.06),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Theme-aware glass base — keeps the panel frosted and
                        // distinct in both light and dark, even over black art.
                        Positioned.fill(child: ColoredBox(color: glassBaseColor)),
                        // 2. The current track's artwork, blurred and glazed, so
                        // the real cover colours shine through the glass without
                        // dictating luminance (a single flat tint reads muddy).
                        Positioned.fill(
                          child: Opacity(opacity: artGlazeOpacity, child: const _NowPlayingBarBlurredArt()),
                        ),
                        // 3. A frosting BackdropFilter + gentle scrim settles the
                        // text contrast while keeping the artwork present.
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                            child: ColoredBox(color: glassScrimColor),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (ref.watch(finampSettingsProvider.showProgressOnNowPlayingBar))
                                  Positioned.fill(child: ColoredBox(color: remainingPartBackgroundColor)),
                                AlbumImage(
                                  placeholderBuilder: (_) => const SizedBox.shrink(),
                                  imageListenable: currentAlbumImageProvider,
                                  borderRadius: BorderRadius.zero,
                                ),
                                if (!showPlayButtonAtEnd)
                                  AudioFadeProgressVisualizerContainer(
                                    key: const Key("AlbumArtAudioFadeProgressVisualizer"),
                                    width: albumImageSize,
                                    height: albumImageSize,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12.0),
                                      bottomLeft: Radius.circular(12.0),
                                    ),
                                    child: IconButton(
                                      tooltip: AppLocalizations.of(context)!.togglePlaybackButtonTooltip,
                                      onPressed: () {
                                        FeedbackHelper.feedback(FeedbackType.light);
                                        unawaited(audioHandler.togglePlayback());
                                      },
                                      color: Colors.white,
                                      icon: Icon(
                                        showPauseButton ? TablerIcons.player_pause : TablerIcons.player_play,
                                        shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 10.0)],
                                        size: 32,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  if (ref.watch(finampSettingsProvider.showProgressOnNowPlayingBar))
                                    Positioned.fill(
                                      child: StreamBuilder<Duration>(
                                        stream: AudioService.position,
                                        initialData: audioHandler.playbackState.value.position,
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            playbackPosition = snapshot.data;
                                            var itemLength = currentTrack.item.duration;
                                            return FractionallySizedBox(
                                              alignment: AlignmentDirectional.centerStart,
                                              widthFactor: itemLength == null
                                                  ? 0
                                                  : max(
                                                      0,
                                                      playbackPosition!.inMilliseconds / itemLength.inMilliseconds,
                                                    ),
                                              child: DecoratedBox(
                                                decoration: ShapeDecoration(
                                                  // Translucent so the played tint layers over the
                                                  // frosted glass instead of an opaque block, keeping
                                                  // the title/artist legible where progress overlaps.
                                                  // The blurred art already carries the accent colour,
                                                  // so this only needs to mark position subtly.
                                                  color: elapsedPartBackgroundColor.withOpacity(0.3),
                                                  shape: const RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.only(
                                                      topRight: Radius.circular(12),
                                                      bottomRight: Radius.circular(12),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else {
                                            return SizedBox.shrink();
                                          }
                                        },
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: albumImageSize,
                                          padding: const EdgeInsets.only(left: 12, right: 4),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              OneLineMarqueeHelper(
                                                key: ValueKey(currentTrack.item.id),
                                                text: currentTrack.item.title,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  height: 26 / 20,
                                                  color: primaryTextColor,
                                                  shadows: textShadows,
                                                  fontWeight: Theme.brightnessOf(context) == Brightness.light
                                                      ? FontWeight.w500
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      processArtist(currentTrack.item.artist, context),
                                                      style: TextStyle(
                                                        color: primaryTextColor,
                                                        shadows: textShadows,
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w400,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  StreamBuilder<Duration>(
                                                    stream: AudioService.position,
                                                    initialData: audioHandler.playbackState.value.position,
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        playbackPosition = snapshot.data;
                                                        final showRemaining = Platform.isIOS || Platform.isMacOS;
                                                        final positionFullMinutes =
                                                            (playbackPosition?.inMinutes ?? 0) % 60;
                                                        final positionFullHours = (playbackPosition?.inHours ?? 0);
                                                        final positionSeconds = (playbackPosition?.inSeconds ?? 0) % 60;
                                                        final durationFullHours =
                                                            (currentTrack.item.duration?.inHours ?? 0);
                                                        final durationFullMinutes =
                                                            (currentTrack.item.duration?.inMinutes ?? 0) % 60;
                                                        final durationSeconds =
                                                            (currentTrack.item.duration?.inSeconds ?? 0) % 60;
                                                        return Semantics.fromProperties(
                                                          properties: SemanticsProperties(
                                                            label:
                                                                "${positionFullHours > 0 ? "$positionFullHours hours " : ""}${positionFullMinutes > 0 ? "$positionFullMinutes minutes " : ""}$positionSeconds seconds of ${durationFullHours > 0 ? "$durationFullHours hours " : ""}${durationFullMinutes > 0 ? "$durationFullMinutes minutes " : ""}$durationSeconds seconds",
                                                          ),
                                                          excludeSemantics: true,
                                                          container: true,
                                                          child: Row(
                                                            children: [
                                                              Text(
                                                                printDuration(
                                                                  showRemaining
                                                                      ? ((currentTrack.item.duration ?? Duration.zero) -
                                                                            (playbackPosition ?? Duration.zero))
                                                                      : playbackPosition,
                                                                  leadingZeroes: false,
                                                                  isRemaining: showRemaining,
                                                                ),
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w400,
                                                                  color: primaryTextColor.withOpacity(0.8),
                                                                  fontFeatures: const [
                                                                    // fixed-width digits
                                                                    FontFeature.tabularFigures(),
                                                                  ],
                                                                ),
                                                              ),
                                                              if (!showRemaining) ...[
                                                                const SizedBox(width: 2),
                                                                Text(
                                                                  '/',
                                                                  style: TextStyle(
                                                                    color: primaryTextColor.withOpacity(0.8),
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.w400,
                                                                    fontFeatures: const [
                                                                      // fixed-width digits
                                                                      FontFeature.tabularFigures(),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 2),
                                                                Text(
                                                                  // '3:44',
                                                                  (currentTrack.item.duration?.inHours ?? 0.0) >= 1.0
                                                                      ? "${currentTrack.item.duration?.inHours.toString()}:${((currentTrack.item.duration?.inMinutes ?? 0) % 60).toString().padLeft(2, '0')}:${((currentTrack.item.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}"
                                                                      : "${currentTrack.item.duration?.inMinutes.toString()}:${((currentTrack.item.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                                                                  style: TextStyle(
                                                                    color: primaryTextColor.withOpacity(0.8),
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.w400,
                                                                    fontFeatures: const [
                                                                      // fixed-width digits
                                                                      FontFeature.tabularFigures(),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        );
                                                      } else {
                                                        return const SizedBox.shrink();
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 5.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            AddToPlaylistButton(
                                              item: currentTrackBaseItem,
                                              queueItem: currentTrack,
                                              color: primaryTextColor,
                                              size: 28,
                                              visualDensity: const VisualDensity(horizontal: -4),
                                            ),

                                            if (showPlayButtonAtEnd)
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  AudioFadeProgressVisualizerContainer(
                                                    key: const Key("AlbumArtAudioFadeProgressVisualizer"),
                                                    color: primaryTextColor.withOpacity(0.5),
                                                    width: albumImageSize,
                                                    height: albumImageSize,
                                                    borderRadius: BorderRadius.circular(12.0),
                                                    child: SizedBox.shrink(),
                                                  ),
                                                  IconButton(
                                                    tooltip: AppLocalizations.of(context)!.togglePlaybackButtonTooltip,
                                                    onPressed: () {
                                                      FeedbackHelper.feedback(FeedbackType.light);
                                                      unawaited(audioHandler.togglePlayback());
                                                    },
                                                    color: primaryTextColor,
                                                    visualDensity: VisualDensity.compact,
                                                    icon: Icon(
                                                      showPauseButton
                                                          ? TablerIcons.player_pause
                                                          : TablerIcons.player_play,
                                                      size: 28,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return Hero(
      tag: "nowplaying",
      createRectTween: (from, to) => RectTween(begin: from, end: from),
      child: PlayerScreenTheme(
        // The now playing bar must be enclosed in a SafeArea at all times so that the enclosing scaffold properly adds
        // bottom padding, even if the now playing bar itself is empty.
        child: SafeArea(
          // use consumer to obtain ref of correct (player screen theme) ProviderContainer
          child: Consumer(
            builder: (context, ref, child) {
              ref.listen(currentTrackMetadataProvider, (metadataOrNull, metadata) {}); // keep provider alive
              return StreamBuilder<FinampQueueInfo?>(
                stream: queueService.getQueueStream(),
                initialData: queueService.getQueue(),
                builder: (context, snapshot) {
                  if (snapshot.hasData &&
                      snapshot.data!.saveState == SavedQueueState.loading &&
                      !usingPlayerSplitScreen) {
                    return buildLoadingQueueBar(ref, null);
                  } else if (snapshot.hasData &&
                      snapshot.data!.saveState == SavedQueueState.failed &&
                      !usingPlayerSplitScreen) {
                    return buildLoadingQueueBar(ref, queueService.retryQueueLoad);
                  } else if (snapshot.hasData && snapshot.data!.currentTrack != null && !usingPlayerSplitScreen) {
                    return buildNowPlayingBar(ref, snapshot.data!.currentTrack!);
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints the current track's album art, heavily blurred and scaled up to fill
/// the now playing bar, so the cover's real colours glow through the frosted
/// glass above it. This is the "shine the special colour" look — the actual
/// artwork rather than a single flat averaged tint (which reads muddy).
class _NowPlayingBarBlurredArt extends ConsumerWidget {
  const _NowPlayingBarBlurredArt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // localImageProvider is overridden to the current track's art by the
    // enclosing PlayerScreenTheme, so this tracks whatever is playing.
    final image = ref.watch(localImageProvider).image;
    if (image == null) {
      return const SizedBox.shrink();
    }
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 32.0, sigmaY: 32.0, tileMode: TileMode.mirror),
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: image,
              fit: BoxFit.cover,
              // A touch of saturation keeps the colour vivid once the frost
              // scrim lightens it, without darkening the artwork.
              colorFilter: const ColorFilter.matrix(<double>[
                1.18, -0.06, -0.06, 0, 0, //
                -0.06, 1.18, -0.06, 0, 0, //
                -0.06, -0.06, 1.18, 0, 0, //
                0, 0, 0, 1, 0, //
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
