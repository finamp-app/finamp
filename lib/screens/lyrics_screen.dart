import 'dart:async';
import 'dart:io';

import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/Buttons/finamp_extended_floating_action_button.dart';
import 'package:finamp/components/PlayerScreen/player_screen_appbar_title.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/extensions/string.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/main.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/current_track_metadata_provider.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/progress_state_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_to_airplay/flutter_to_airplay.dart';
import 'package:get_it/get_it.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import '../components/PlayerScreen/control_area.dart';
import '../components/PlayerScreen/player_screen_album_image.dart';
import '../components/PlayerScreen/queue_list.dart';
import '../components/PlayerScreen/track_name_content.dart';
import '../components/finamp_app_bar_back_button.dart';
import '../services/finamp_settings_helper.dart';
import '../services/theme_provider.dart';
import 'blurred_player_screen_background.dart';
import 'player_screen.dart';

class LyricsScreen extends StatelessWidget {
  const LyricsScreen({super.key});

  static const routeName = "/lyrics";

  @override
  Widget build(BuildContext context) {
    return PlayerScreenTheme(child: const _LyricsScreenContent());
  }
}

class _LyricsScreenContent extends ConsumerStatefulWidget {
  const _LyricsScreenContent();

  @override
  ConsumerState<_LyricsScreenContent> createState() => _LyricsScreenContentState();
}

class _LyricsScreenContentState extends ConsumerState<_LyricsScreenContent> {
  @override
  Widget build(BuildContext context) {
    double toolbarHeight = 53;
    int maxLines = 2;

    var controller = PlayerHideableController();

    return SimpleGestureDetector(
      onVerticalSwipe: (direction) {
        if (direction == SwipeDirection.up) {
          // This should never actually be called until widget finishes build and controller is initialized
          if (!FinampSettingsHelper.finampSettings.disableGesture ||
              !controller.shouldShow(PlayerHideable.bottomActions)) {
            showQueueBottomSheet(context, ref);
          }
        }
      },
      onHorizontalSwipe: (direction) {
        if (direction == SwipeDirection.right) {
          if (!FinampSettingsHelper.finampSettings.disableGesture) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Disable tint/shadow when content is scrolled under the app bar
          scrolledUnderElevation: 0.0,
          centerTitle: true,
          toolbarHeight: toolbarHeight,
          title: PlayerScreenAppBarTitle(maxLines: maxLines),
          leading: FinampAppBarBackButton(dismissDirection: AxisDirection.right),
          actions: [
            if (Platform.isIOS)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AirPlayRoutePickerView(
                  tintColor: IconTheme.of(context).color ?? Colors.white,
                  activeTintColor: jellyfinBlueColor,
                  onShowPickerView: () => FeedbackHelper.feedback(FeedbackType.selection),
                ),
              ),
          ],
        ),
        // Required for sleep timer input
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            if (ref.watch(finampSettingsProvider.useCoverAsBackground)) const BlurredPlayerScreenBackground(),
            SafeArea(
              minimum: EdgeInsets.only(top: toolbarHeight),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  controller.setSize(
                    Size(constraints.maxWidth, constraints.maxHeight),
                    MediaQuery.orientationOf(context),
                    ref,
                  );
                  if (controller.useLandscape) {
                    return const LyricsView();
                  } else {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Expanded(child: LyricsView()),
                        SimpleGestureDetector(
                          onVerticalSwipe: (direction) {
                            if (direction == SwipeDirection.up) {
                              // This should never actually be called until widget finishes build and controller is initialized
                              if (!FinampSettingsHelper.finampSettings.disableGesture) {
                                showQueueBottomSheet(context, ref);
                              }
                            }
                          },
                          child: Column(
                            children: [
                              TrackNameContent(controller),
                              ControlArea(controller),
                              const SizedBox(height: 12),
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
    );
  }
}

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> with WidgetsBindingObserver {
  late AutoScrollController autoScrollController;
  StreamSubscription<ProgressState>? progressStateStreamSubscription;
  // Ranges from -1 to lyricLines.length - 1
  final ValueNotifier<int?> currentLineNotifier = ValueNotifier(null);

  bool isAutoScrollEnabled = true;

  bool _isVisible = true;
  bool get _isSynchronizedLyrics => lyrics?.firstOrNull?.start != null;
  List<LyricLine>? lyrics;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    autoScrollController = AutoScrollController(
      suggestedRowHeight: 72,
      viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.paddingOf(context).bottom),
      axis: Axis.vertical,
    );

    autoScrollController.addListener(() {
      var position = autoScrollController.position;
      if (position.userScrollDirection != ScrollDirection.idle && _isSynchronizedLyrics && isAutoScrollEnabled) {
        setState(() {
          isAutoScrollEnabled = false;
        });
      }
    });

    progressStateStreamSubscription = progressStateStream.listen((state) {
      final currentMicros = state.position.inMicroseconds;

      if (!_isSynchronizedLyrics || !_isVisible || !mounted) {
        return;
      }
      final lyricLines = lyrics!;

      // Find the closest line to the current position, clamping to the first and last lines
      int closestLineIndex = -1;
      for (int i = 0; i < lyricLines.length; i++) {
        closestLineIndex = i;
        final line = lyricLines[i];
        if (line.startMicros > currentMicros) {
          closestLineIndex = i - 1;
          break;
        }
      }
      closestLineIndex = closestLineIndex.clamp(-1, lyricLines.length - 1);

      if (currentLineNotifier.value != closestLineIndex && mounted) {
        currentLineNotifier.value = closestLineIndex; // Rebuild to update the current line
        if (autoScrollController.hasClients && isAutoScrollEnabled) {
          MediaQuery.disableAnimationsOf(context);
          if (closestLineIndex < 0) {
            unawaited(
              autoScrollController.scrollToIndex(
                -1,
                preferPosition: AutoScrollPosition.middle,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? const Duration(
                        milliseconds: 1,
                      ) // there's an assertion in the library forbidding a duration of 0, so we use 1ms instead to get instant scrolling
                    : const Duration(milliseconds: 300),
              ),
            );
          } else {
            unawaited(
              autoScrollController.scrollToIndex(
                closestLineIndex,
                preferPosition: AutoScrollPosition.middle,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? const Duration(
                        milliseconds: 1,
                      ) // there's an assertion in the library forbidding a duration of 0, so we use 1ms instead to get instant scrolling
                    : const Duration(milliseconds: 300),
              ),
            );
          }
        }
      }
    });

    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = [AppLifecycleState.resumed, AppLifecycleState.inactive].contains(state);
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    progressStateStreamSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    autoScrollController.dispose();
    currentLineNotifier.dispose();
    super.dispose();
  }

  // Only call while within build()
  Widget _getEmptyState({required String message, required IconData icon}) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight - 180),
                child: ref.watch(finampSettingsProvider.showLyricsScreenAlbumPrelude)
                    ? const PlayerScreenAlbumImage()
                    : SizedBox(),
              ),
              const SizedBox(height: 24),
              Icon(icon, size: 32, color: Theme.of(context).textTheme.headlineMedium!.color),
              const SizedBox(height: 12),
              Text(message, style: TextStyle(color: Theme.of(context).textTheme.headlineMedium!.color, fontSize: 16)),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //!!! use unwrapPrevious() to prevent getting previous values. If we don't have the lyrics for the current track yet, we want to show the loading state, and not the lyrics for the previous track
    final metadata = ref.watch(currentTrackMetadataProvider).unwrapPrevious();
    lyrics = metadata.valueOrNull?.lyrics?.lyrics;
    if (!_isSynchronizedLyrics) {
      currentLineNotifier.value = null;
    }

    if ((metadata.isLoading && !metadata.hasValue) || metadata.isRefreshing) {
      return _getEmptyState(
        message: AppLocalizations.of(context)!.lyricsEmptyStateLoading,
        icon: TablerIcons.microphone_2,
      );
    } else if (!metadata.hasValue ||
        metadata.value == null ||
        metadata.value!.hasLyrics && metadata.value!.lyrics == null && !metadata.isLoading) {
      return _getEmptyState(
        message: AppLocalizations.of(context)!.lyricsEmptyStateFailed,
        icon: TablerIcons.microphone_2_off,
      );
    } else if (!metadata.value!.hasLyrics) {
      return _getEmptyState(
        message: AppLocalizations.of(context)!.lyricsEmptyStateNoLyrics,
        icon: TablerIcons.microphone_2_off,
      );
    } else {
      // We have lyrics that we can display
      final lyricLines = lyrics ?? [];

      return LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 12.0),
            child: Stack(
              children: [
                // Manually build scrollbar above lyricsListMask
                Scrollbar(
                  controller: autoScrollController,
                  // Use notificationPredicate from LyricsScrollBehavior
                  notificationPredicate: (notification) {
                    if (notification.depth != 0) return false;
                    if (autoScrollController.isAutoScrolling) {
                      if (notification is ScrollUpdateNotification && notification.scrollDelta == null) {
                        return true;
                      }
                      return false;
                    }
                    return true;
                  },
                  child: ScrollConfiguration(
                    behavior: const FinampScrollBehavior(scrollbars: false),
                    child: LyricsListMask(
                      child: ListView.builder(
                        key: PageStorageKey(metadata.valueOrNull?.item),
                        controller: autoScrollController,
                        itemCount: lyricLines.length + 2,
                        itemBuilder: (context, rawIndex) {
                          if (rawIndex == 0) {
                            // build header
                            return AutoScrollTag(
                              key: const ValueKey(-1),
                              controller: autoScrollController,
                              index: -1,
                              child: ref.watch(finampSettingsProvider.showLyricsScreenAlbumPrelude)
                                  ? SizedBox(
                                      height: constraints.maxHeight * 0.65,
                                      child: Center(
                                        child: SizedBox(
                                          height: constraints.maxHeight * 0.55,
                                          child: const PlayerScreenAlbumImage(),
                                        ),
                                      ),
                                    )
                                  : SizedBox(height: constraints.maxHeight * 0.2),
                            );
                          } else if (rawIndex == lyricLines.length + 1) {
                            // build footer
                            return SizedBox(height: constraints.maxHeight * 0.2);
                          } else {
                            final index = rawIndex - 1;
                            final line = lyricLines[index];
                            return AutoScrollTag(
                              key: ValueKey(index),
                              controller: autoScrollController,
                              index: index,
                              child: _LyricLine(
                                lineNumber: index,
                                line: line,
                                onTap: () async {
                                  // Seek to the start of the line + 1 millisecond to account for player inaccuracy
                                  await GetIt.instance<MusicPlayerBackgroundTask>().seek(
                                    Duration(microseconds: line.startMicros + 1000),
                                  );
                                  setState(() {
                                    isAutoScrollEnabled = true;
                                  });
                                  if (!context.mounted) return;
                                  unawaited(
                                    autoScrollController.scrollToIndex(
                                      index,
                                      preferPosition: AutoScrollPosition.middle,
                                      duration: MediaQuery.disableAnimationsOf(context)
                                          ? const Duration(
                                              milliseconds: 1,
                                            ) // there's an assertion in the library forbidding a duration of 0, so we use 1ms instead to get instant scrolling
                                          : const Duration(milliseconds: 500),
                                    ),
                                  );
                                },
                                currentLineNumberNotifier: currentLineNotifier,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                if (_isSynchronizedLyrics)
                  Positioned(
                    bottom: 24,
                    right: 0,
                    child: EnableAutoScrollButton(
                      autoScrollEnabled: isAutoScrollEnabled,
                      onEnableAutoScroll: () {
                        setState(() {
                          isAutoScrollEnabled = true;
                        });
                        if (currentLineNotifier.value != null) {
                          unawaited(
                            autoScrollController.scrollToIndex(
                              currentLineNotifier.value!,
                              preferPosition: AutoScrollPosition.middle,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? const Duration(
                                      milliseconds: 1,
                                    ) // there's an assertion in the library forbidding a duration of 0, so we use 1ms instead to get instant scrolling
                                  : const Duration(milliseconds: 500),
                            ),
                          );
                        }
                        FeedbackHelper.feedback(FeedbackType.heavy);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
  }
}

class _LyricLine extends ConsumerWidget {
  final LyricLine line;
  final VoidCallback? onTap;
  final int lineNumber;
  final ValueNotifier<int?> currentLineNumberNotifier;

  const _LyricLine({required this.line, required this.lineNumber, required this.currentLineNumberNotifier, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSynchronized = line.start != null;
    final showTimestamp =
        isSynchronized && !line.text.isNullOrBlank && ref.watch(finampSettingsProvider.showLyricsTimestamps);

    final unSyncedStyle = TextStyle(
      color: Theme.of(context).textTheme.bodyLarge!.color,
      fontWeight: FontWeight.normal,
      // Keep text width consistent across the different weights
      letterSpacing: -0.4,
      fontSize: lyricsFontSizeToSize(ref.watch(finampSettingsProvider.lyricsFontSize)).toDouble(),
    );
    final currentLineStyle = unSyncedStyle;
    final lowlightStyle = unSyncedStyle.copyWith(color: Colors.grey);
    // ensure we use a highlight color that has decent contrast against the non-cue current line text color
    final highlightColor = Theme.of(context).colorScheme.primary.contrastAgainst(currentLineStyle.color!) < 1.25
        ? jellyfinBlueColor
        : Theme.of(context).colorScheme.primary;
    // final cueHighlightStyle = currentLineStyle.copyWith(color: Theme.of(context).colorScheme.primary);
    final cueHighlightStyle = currentLineStyle.copyWith(color: highlightColor);
    final cueGreyStyle = currentLineStyle.copyWith(color: Colors.white);
    final cueFadeStyle = currentLineStyle.copyWith(
      color: Color.alphaBlend(highlightColor.withOpacity(0.6), Colors.white),
    );

    return GestureDetector(
      onTap: isSynchronized ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isSynchronized ? 10.0 : 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ValueListenableBuilder(
                  valueListenable: currentLineNumberNotifier,
                  builder: (context, value, _) {
                    return Text(
                      "${Duration(microseconds: line.startMicros).inMinutes}:${(Duration(microseconds: line.startMicros).inSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: isSynchronized && value != lineNumber ? lowlightStyle.color : unSyncedStyle.color,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _LyricLineText(
                line: line,
                lineNumber: lineNumber,
                currentLineNumberNotifier: currentLineNumberNotifier,
                lowlightStyle: lowlightStyle,
                cueGreyStyle: cueGreyStyle,
                cueHighlightStyle: cueHighlightStyle,
                unSyncedStyle: unSyncedStyle,
                currentLineStyle: currentLineStyle,
                cueFadeStyle: cueFadeStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricLineText extends ConsumerStatefulWidget {
  final LyricLine line;
  final int lineNumber;
  final ValueNotifier<int?> currentLineNumberNotifier;
  final TextStyle lowlightStyle;
  final TextStyle unSyncedStyle;
  final TextStyle currentLineStyle;
  final TextStyle cueGreyStyle;
  final TextStyle cueFadeStyle;
  final TextStyle cueHighlightStyle;

  bool get _useCues => line.cues != null && line.cues!.isNotEmpty;
  bool get _isSynced => line.start != null;

  const _LyricLineText({
    required this.line,
    required this.lineNumber,
    required this.currentLineNumberNotifier,
    required this.lowlightStyle,
    required this.cueGreyStyle,
    required this.cueHighlightStyle,
    required this.unSyncedStyle,
    required this.currentLineStyle,
    required this.cueFadeStyle,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LyricLineTextState();
}

class _LyricLineTextState extends ConsumerState<_LyricLineText> {
  InlineSpan? textSpan;
  bool isCurrentLine = false;
  StreamSubscription<ProgressState>? cueStream;

  @override
  void initState() {
    widget.currentLineNumberNotifier.addListener(_updateCurrentTrack);
    _updateCurrentTrack();
    super.initState();
  }

  void _updateCurrentTrack({bool force = false}) {
    bool isCurrent = widget.currentLineNumberNotifier.value == widget.lineNumber;
    bool requireUpdate = force || textSpan == null;
    if (isCurrent && (!isCurrentLine || requireUpdate)) {
      isCurrentLine = isCurrent;
      cueStream?.cancel();
      if (widget._useCues) {
        _updateTextFromCues(GetIt.instance<MusicPlayerBackgroundTask>().playbackState.value.position.inMicroseconds);
        cueStream = progressStateStream.listen((state) => _updateTextFromCues(state.position.inMicroseconds));
      } else {
        _updateTextWithoutCues();
      }
    } else if (!isCurrent && (isCurrentLine || requireUpdate)) {
      isCurrentLine = isCurrent;
      cueStream?.cancel();
      _updateTextWithoutCues();
    }
  }

  void _updateTextFromCues(int currentMicros) {
    assert(isCurrentLine && widget._useCues);
    final text = widget.line.text;

    if (text == null || text.isEmpty) {
      setState(() {
        textSpan = TextSpan(
          text: text ?? "<${AppLocalizations.of(context)!.lyricsMissingLyricLinePlaceholder}>",
          style: widget.currentLineStyle,
        );
      });
      return;
    }

    // Calculate per-letter styling by starting with cueGrey and applying highlighting
    // and fades for appropriate cues.
    List<TextStyle> letterStyles = List.filled(text.length, widget.cueGreyStyle);
    final cueList = widget.line.cues!;
    for (int i = 0; i < cueList.length; i++) {
      final cue = cueList[i];
      final nextCue = i + 1 < cueList.length ? cueList[i + 1] : null;
      final endPosition = cue.endPosition ?? nextCue?.position ?? text.length;
      final endTime = cue.endMicros ?? nextCue?.startMicros;
      if (endPosition - cue.position <= 0) continue;

      // Check if this word is currently being sung
      final hasReachedThisCue = currentMicros >= cue.startMicros;
      final hasPassedCue = endTime != null && currentMicros >= endTime;

      // Calculate fade-in timing (0.5 seconds = 500,000 microseconds before the cue)
      const fadeInDurationMicros = 500000; // 0.5 seconds
      final fadeInStartTime = cue.startMicros - fadeInDurationMicros;
      final isInFadeInPeriod = currentMicros >= fadeInStartTime && !hasReachedThisCue;

      if (hasReachedThisCue && !hasPassedCue) {
        // This word/segment is currently active - highlight it
        for (int i = cue.position; i < endPosition; i++) {
          letterStyles[i] = widget.cueHighlightStyle;
        }
      } else if (isInFadeInPeriod) {
        // This word is about to become active - fade it in letter by letter with color change
        final fadeProgress = (currentMicros - fadeInStartTime) / fadeInDurationMicros;
        final totalLetters = endPosition - cue.position;
        final highlightedLetters = (totalLetters * fadeProgress).round();
        final int fadeEndPosition = (cue.position + highlightedLetters).clamp(cue.position, endPosition);

        for (int i = cue.position; i < fadeEndPosition; i++) {
          letterStyles[i] = widget.cueFadeStyle;
        }
      }
    }

    // Gather letter-by-letter styling into text spans
    TextStyle previousStyle = letterStyles[0];
    int lastAdded = 0;
    List<TextSpan> segments = [];
    for (int i = 1; i < letterStyles.length; i++) {
      final newStyle = letterStyles[i];
      if (identical(previousStyle, newStyle)) continue;
      segments.add(TextSpan(text: text.substring(lastAdded, i), style: previousStyle));
      lastAdded = i;
      previousStyle = newStyle;
    }
    segments.add(TextSpan(text: text.substring(lastAdded, letterStyles.length), style: previousStyle));

    setState(() {
      textSpan = TextSpan(children: segments);
    });
  }

  void _updateTextWithoutCues() {
    setState(() {
      if (!widget._isSynced) {
        textSpan = TextSpan(
          text: widget.line.text ?? "<${AppLocalizations.of(context)!.lyricsMissingLyricLinePlaceholder}>",
          style: widget.unSyncedStyle,
        );
      } else if (!isCurrentLine) {
        textSpan = TextSpan(
          text: widget.line.text ?? "<${AppLocalizations.of(context)!.lyricsMissingLyricLinePlaceholder}>",
          style: widget.lowlightStyle,
        );
      } else {
        assert(!widget._useCues);
        textSpan = TextSpan(
          text: widget.line.text ?? "<${AppLocalizations.of(context)!.lyricsMissingLyricLinePlaceholder}>",
          style: widget.currentLineStyle,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LyricLineText oldWidget) {
    if (widget.currentLineNumberNotifier != oldWidget.currentLineNumberNotifier) {
      oldWidget.currentLineNumberNotifier.removeListener(_updateCurrentTrack);
      widget.currentLineNumberNotifier.addListener(_updateCurrentTrack);
    }
    if (widget.line != oldWidget.line || widget.lineNumber != oldWidget.lineNumber) {
      _updateCurrentTrack(force: true);
    } else if (isCurrentLine) {
      if (widget._useCues) {
        if (widget.cueHighlightStyle != oldWidget.cueHighlightStyle ||
            widget.cueGreyStyle != oldWidget.cueGreyStyle ||
            widget.cueFadeStyle != oldWidget.cueFadeStyle) {
          _updateCurrentTrack(force: true);
        }
      } else {
        if (widget.currentLineStyle != oldWidget.currentLineStyle) {
          _updateCurrentTrack(force: true);
        }
      }
    } else {
      if (widget._isSynced) {
        if (widget.lowlightStyle != oldWidget.lowlightStyle) {
          _updateCurrentTrack(force: true);
        }
      } else {
        if (widget.unSyncedStyle != oldWidget.unSyncedStyle) {
          _updateCurrentTrack(force: true);
        }
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.currentLineNumberNotifier.removeListener(_updateCurrentTrack);
    cueStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: textSpan!,
      textAlign: lyricsAlignmentToTextAlign(ref.watch(finampSettingsProvider.lyricsAlignment)),
    );
  }
}

class LyricsListMask extends StatelessWidget {
  const LyricsListMask({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.5),
            Colors.white,
            Colors.white,
            Colors.white.withOpacity(0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.05, 0.10, 0.90, 0.95, 1.0],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class EnableAutoScrollButton extends StatelessWidget {
  final bool autoScrollEnabled;
  final VoidCallback? onEnableAutoScroll;

  const EnableAutoScrollButton({super.key, required this.autoScrollEnabled, this.onEnableAutoScroll});

  @override
  Widget build(BuildContext context) {
    return !autoScrollEnabled
        ? FinampExtendedFloatingActionButton(
            onTap: () {
              FeedbackHelper.feedback(FeedbackType.heavy);
              onEnableAutoScroll?.call();
            },
            icon: TablerIcons.arrow_bar_to_up,
            label: AppLocalizations.of(context)!.enableAutoScroll,
          )
        : const SizedBox.shrink();
  }
}

TextAlign lyricsAlignmentToTextAlign(LyricsAlignment alignment) {
  switch (alignment) {
    case LyricsAlignment.start:
      return TextAlign.start;
    case LyricsAlignment.center:
      return TextAlign.center;
    case LyricsAlignment.end:
      return TextAlign.end;
  }
}

int lyricsFontSizeToSize(LyricsFontSize fontSize) {
  switch (fontSize) {
    case LyricsFontSize.small:
      return 20;
    case LyricsFontSize.medium:
      return 26;
    case LyricsFontSize.large:
      return 32;
  }
}

class LyricsScrollBehavior extends MaterialScrollBehavior {
  const LyricsScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final controller = details.controller;
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        assert(controller != null);
        return Scrollbar(
          controller: controller,
          notificationPredicate: (notification) {
            if (notification.depth != 0) return false;
            if (controller is AutoScrollController && controller.isAutoScrolling) {
              if (notification is ScrollUpdateNotification && notification.scrollDelta == null) {
                return true;
              }
              return false;
            }
            return true;
          },
          child: child,
        );
    }
  }
}
