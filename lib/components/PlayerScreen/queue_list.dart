import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/AlbumScreen/track_list_tile.dart';
import 'package:finamp/components/Buttons/finamp_extended_floating_action_button.dart';
import 'package:finamp/components/Buttons/simple_button.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/audio_fade_progress_visualizer_container.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/components/one_line_marquee_helper.dart';
import 'package:finamp/components/padded_custom_scrollview.dart';
import 'package:finamp/components/print_duration.dart';
import 'package:finamp/components/themed_bottom_sheet.dart';
import 'package:finamp/extensions/color_extensions.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/main.dart';
import 'package:finamp/menus/choice_menu.dart';
import 'package:finamp/menus/components/icon_button_with_semantics.dart';
import 'package:finamp/menus/components/radio_mode_menu.dart';
import 'package:finamp/menus/track_menu.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart' as jellyfin_models;
import 'package:finamp/screens/blurred_player_screen_background.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/media_state_stream.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/process_artist.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/radio_service_helper.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import '../../extensions/localizations.dart';

class QueueListStreamState {
  QueueListStreamState(this.mediaState, this.queueInfo);

  final MediaState mediaState;
  final FinampQueueInfo? queueInfo;
}

class QueueList extends ConsumerStatefulWidget {
  static const routeName = "/queue";

  const QueueList({
    super.key,
    required this.scrollController,
    required this.previousTracksHeaderKey,
    required this.jumpToCurrentKey,
  });

  final ScrollController scrollController;

  // Used to jump to current track
  final GlobalKey previousTracksHeaderKey;

  // Used to control appearance of jump to current button
  final GlobalKey<JumpToCurrentButtonState> jumpToCurrentKey;

  @override
  ConsumerState<QueueList> createState() => _QueueListState();
}

void scrollToKey({required GlobalKey key, Duration duration = const Duration(milliseconds: 500)}) async {
  // Wait for any queue rebuilds the caller may have induced to complete before beginning animation
  // It seem that that RenderSliver may take several frames to actually change size after the queue rebuilds, so just
  // add a delay.
  // TODO either watch for previous tracks renderobject to be correct height or just calculate scroll offset ourselves without delay.
  await Future<void>.delayed(Duration(milliseconds: 200));
  await Scrollable.ensureVisible(
    key.currentContext!,
    duration: MediaQuery.disableAnimationsOf(key.currentContext!) ? Duration.zero : duration,
    curve: Curves.easeInOutCubic,
    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
  );
}

class _QueueListState extends ConsumerState<QueueList> {
  final _queueService = GetIt.instance<QueueService>();

  QueueItemSource? _source;
  late int _previousTrackCount;

  bool _performInitialJump = true;

  late List<Widget> _contents;

  // Used to jump when changing playback order
  final nextUpHeaderKey = GlobalKey();
  final queueHeaderKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _queueService.getQueueStream().listen((queueInfo) {
      _source = queueInfo?.source;
      _previousTrackCount = queueInfo?.previousTracks.length ?? 0;
    });

    _source = _queueService.getQueue().source;
    _previousTrackCount = _queueService.getQueue().previousTracks.length;

    _contents = <Widget>[];

    widget.scrollController.addListener(_updateJumpToTop);

    switch (FinampSettingsHelper.finampSettings.previousTracksPersistenceMode) {
      case PreviousTracksPersistenceMode.persistent:
        break;
      case PreviousTracksPersistenceMode.initiallyCollapsed:
        FinampSetters.setPreviousTracksExpanded(false);
        break;
      case PreviousTracksPersistenceMode.initiallyExpanded:
        FinampSetters.setPreviousTracksExpanded(true);
        break;
    }
  }

  void _updateJumpToTop() {
    if (widget.jumpToCurrentKey.currentContext == null) return;
    final screenHeight = MediaQuery.heightOf(widget.jumpToCurrentKey.currentContext!);
    final currentTrackOffset = FinampSettingsHelper.finampSettings.previousTracksExpanded
        ? (_previousTrackCount * QueueListTile.height)
        : 0;
    double offset = widget.scrollController.offset - currentTrackOffset;
    int jumpDirection = 0;
    if (offset > screenHeight * 0.5) {
      jumpDirection = -1;
    } else if (offset < -screenHeight) {
      jumpDirection = 1;
    }
    widget.jumpToCurrentKey.currentState?.showJumpToTop = jumpDirection;
  }

  @override
  Widget build(BuildContext context) {
    if (_performInitialJump) {
      _performInitialJump = false;
      // DraggableScrollableSheet does not expose ScrollController.onAttach or initialScrollOffset for us, so we must
      // wait until the build completes before updating the scroll.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            widget.scrollController.hasClients &&
            FinampSettingsHelper.finampSettings.previousTracksExpanded) {
          final changeHeight = _queueService.getQueue().previousTracks.length * QueueListTile.height;
          var target = widget.scrollController.position.pixels + changeHeight - 50;
          target = target.clamp(
            widget.scrollController.position.minScrollExtent,
            widget.scrollController.position.maxScrollExtent,
          );
          widget.scrollController.position.correctPixels(target);
        }
      });
    }

    _contents = <Widget>[
      // Previous Tracks
      // nested consumer to contain rebuilds
      Consumer(
        builder: (context, ref, child) {
          if (ref.watch(finampSettingsProvider.previousTracksExpanded)) {
            return PreviousTracksList(previousTracksHeaderKey: widget.previousTracksHeaderKey);
          } else {
            return const SliverToBoxAdapter();
          }
        },
      ),
      SliverPersistentHeader(
        key: widget.previousTracksHeaderKey,
        delegate: PreviousTracksSectionHeader(
          previousTracksHeaderKey: widget.previousTracksHeaderKey,
          onTap: () {
            final expanded = !FinampSettingsHelper.finampSettings.previousTracksExpanded;
            FinampSetters.setPreviousTracksExpanded(expanded);

            if (!widget.scrollController.hasClients) return;
            final changeHeight = _queueService.getQueue().previousTracks.length * QueueListTile.height;
            widget.scrollController.position.correctBy(expanded ? changeHeight : -changeHeight);
            if (expanded) {
              widget.scrollController.animateTo(
                widget.scrollController.offset - 100,
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
            }
          },
        ),
      ),
      const CurrentTrack(),
      // next up
      SliverToBoxAdapter(key: nextUpHeaderKey),
      StreamBuilder(
        stream: _queueService.getQueueStream(),
        initialData: _queueService.getQueue(),
        builder: (context, snapshot) {
          if (snapshot.data != null && snapshot.data!.nextUp.isNotEmpty) {
            return SliverStickyHeader(
              header: NextUpSectionHeader(controls: true),
              sliver: NextUpTracksList(previousTracksHeaderKey: widget.previousTracksHeaderKey),
            );
          } else {
            return const SliverToBoxAdapter();
          }
        },
      ),
      // Queue
      // Scrolling to floating headers doesn't work properly, so place the key in a dedicated sliver
      SliverToBoxAdapter(key: queueHeaderKey),
      SliverStickyHeader(
        header: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.antiAlias,
          child: QueueSectionHeader(
            source: _source,
            title: Row(
              children: [
                Text(
                  "${AppLocalizations.of(context)!.playingFrom} ",
                  style: const TextStyle(fontWeight: FontWeight.w300),
                ),
                Flexible(
                  child: Text(
                    _source?.name.getLocalized(context.l10n) ?? AppLocalizations.of(context)!.unknownName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            controls: true,
            nextUpHeaderKey: nextUpHeaderKey,
            queueHeaderKey: queueHeaderKey,
            scrollController: widget.scrollController,
          ),
        ),
        sliver: QueueTracksList(previousTracksHeaderKey: widget.previousTracksHeaderKey),
      ),
    ];

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary.withOpacity(0.7)),
        trackColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        radius: const Radius.circular(6.0),
        thickness: WidgetStateProperty.all(12.0),
        // thumbVisibility: MaterialStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
      ),
      child: PaddedCustomScrollview(
        controller: widget.scrollController,
        scrollBehavior: const FinampScrollBehavior(interactive: true),
        physics: const BouncingScrollPhysics(),
        slivers: _contents,
        // Additional padding to allow for the jump to current track button
        bottomPadding: 90.0,
      ),
    );
  }
}

Future<dynamic> showQueueBottomSheet(BuildContext context, WidgetRef ref) {
  GlobalKey previousTracksHeaderKey = GlobalKey();
  GlobalKey<JumpToCurrentButtonState> jumpToCurrentKey = GlobalKey();

  FeedbackHelper.feedback(FeedbackType.heavy);

  final menu = PlayerScreenTheme(
    child: Consumer(
      builder: (context, ref, child) {
        final halfOpened = ref.watch(halfOpenFoldableProvider);
        return DraggableScrollableSheet(
          snap: false,
          snapAnimationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          // Cover the whole sub screen when in half opened mode
          initialChildSize: halfOpened ? 1.0 : 0.92,
          minChildSize: halfOpened ? 1.0 : 0.25,
          expand: false,
          builder: (context, scrollController) {
            return Scaffold(
              body: Stack(
                children: [
                  if (ref.watch(finampSettingsProvider.useCoverAsBackground))
                    BlurredPlayerScreenBackground(
                      opacityFactor: Theme.brightnessOf(context) == Brightness.dark ? 1.0 : 0.85,
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).textTheme.bodySmall!.color!,
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.of(context)!.queue,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge!.color!,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: QueueList(
                          scrollController: scrollController,
                          previousTracksHeaderKey: previousTracksHeaderKey,
                          jumpToCurrentKey: jumpToCurrentKey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              floatingActionButton: JumpToCurrentButton(
                key: jumpToCurrentKey,
                previousTracksHeaderKey: previousTracksHeaderKey,
              ),
            );
          },
        );
      },
    ),
  );

  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
    isScrollControlled: true,
    enableDrag: true,
    useSafeArea: true,
    routeSettings: const RouteSettings(name: QueueList.routeName),
    constraints: BoxConstraints(maxWidth: double.infinity),
    clipBehavior: Clip.antiAlias,
    // Anchor to bottom right sub screen, required for foldables
    // On book-style foldables, this will anchor to the right half of the screen.
    // On flip-style foldables, this will anchor to the bottom half of the screen.
    anchorPoint: Offset(double.maxFinite, double.maxFinite),
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = (constraints.maxWidth * 0.9).clamp(640, 900);
        return ConstrainedBox(
          constraints: constraints.copyWith(maxWidth: maxWidth),
          child: menu,
        );
      },
    ),
  );
}

class JumpToCurrentButton extends StatefulWidget {
  const JumpToCurrentButton({super.key, required this.previousTracksHeaderKey});

  final GlobalKey previousTracksHeaderKey;

  @override
  State<JumpToCurrentButton> createState() => JumpToCurrentButtonState();
}

class JumpToCurrentButtonState extends State<JumpToCurrentButton> {
  int _jumpToCurrentTrackDirection = 0;

  set showJumpToTop(int direction) {
    if (direction != _jumpToCurrentTrackDirection) {
      setState(() {
        _jumpToCurrentTrackDirection = direction;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _jumpToCurrentTrackDirection != 0
        ? FinampExtendedFloatingActionButton(
            icon: _jumpToCurrentTrackDirection < 0 ? TablerIcons.arrow_bar_to_up : TablerIcons.arrow_bar_to_down,
            label: AppLocalizations.of(context)!.scrollToCurrentTrack,
            onTap: () {
              FeedbackHelper.feedback(FeedbackType.heavy);
              scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
            },
          )
        : const SizedBox.shrink();
  }
}

class PreviousTracksList extends StatefulWidget {
  final GlobalKey previousTracksHeaderKey;

  const PreviousTracksList({super.key, required this.previousTracksHeaderKey});

  @override
  State<PreviousTracksList> createState() => _PreviousTracksListState();
}

class _PreviousTracksListState extends State<PreviousTracksList> with TickerProviderStateMixin {
  final _queueService = GetIt.instance<QueueService>();
  List<FinampQueueItem>? _previousTracks;

  @override
  Widget build(context) {
    return MenuMask(
      height: MenuMaskHeight(0.0),
      child: StreamBuilder<FinampQueueInfo?>(
        stream: _queueService.getQueueStream(),
        initialData: _queueService.getQueue(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _previousTracks ??= snapshot.data!.previousTracks;
            return SliverReorderableList(
              proxyDecorator: (widget, _, _) => Material(type: MaterialType.transparency, child: widget),
              autoScrollerVelocityScalar: 20.0,
              onReorder: (oldIndex, newIndex) {
                int draggingOffset = -(_previousTracks!.length - oldIndex);
                int newPositionOffset = -(_previousTracks!.length - newIndex);
                if (mounted) {
                  FeedbackHelper.feedback(FeedbackType.heavy);
                  setState(() {
                    // temporarily update internal queue
                    FinampQueueItem tmp = _previousTracks!.removeAt(oldIndex);
                    _previousTracks!.insert(newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                    // update external queue to commit changes, results in a rebuild
                    _queueService.reorderByOffset(draggingOffset, newPositionOffset);
                  });
                }
              },
              onReorderStart: (p0) {
                FeedbackHelper.feedback(FeedbackType.selection);
              },
              findChildIndexCallback: (Key key) {
                key = key as GlobalObjectKey;
                final ValueKey<String> valueKey = key.value as ValueKey<String>;
                // search from the back as this is probably more efficient for previous tracks
                final index = _previousTracks!.lastIndexWhere((item) => item.id == valueKey.value);
                if (index == -1) return null;
                return index;
              },
              itemCount: _previousTracks?.length ?? 0,
              itemExtent: QueueListTile.height,
              itemBuilder: (context, index) {
                final item = _previousTracks![index];
                final indexOffset = -((_previousTracks?.length ?? 0) - index);
                return QueueListTile(
                  key: ValueKey(item.id),
                  item: item.baseItem,
                  listIndex: index,
                  isInPlaylist: queueItemInPlaylist(item),
                  parentItem: item.source.item,
                  queueItem: item,
                  allowReorder: true,
                  onTap: (bool playable) async {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    await _queueService.skipByOffset(indexOffset);
                    scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
                  },
                  onRemoveFromList: () {
                    unawaited(_queueService.removeAtOffset(indexOffset));
                  },
                  isCurrentTrack: false,
                );
              },
            );
          } else {
            return SliverList(delegate: SliverChildListDelegate([]));
          }
        },
      ),
    );
  }
}

class NextUpTracksList extends StatefulWidget {
  final GlobalKey previousTracksHeaderKey;

  const NextUpTracksList({super.key, required this.previousTracksHeaderKey});

  @override
  State<NextUpTracksList> createState() => _NextUpTracksListState();
}

class _NextUpTracksListState extends State<NextUpTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<FinampQueueItem>? _nextUp;

  @override
  Widget build(context) {
    return MenuMask(
      height: NextUpSectionHeader.defaultHeight,
      child: StreamBuilder<FinampQueueInfo?>(
        stream: _queueService.getQueueStream(),
        initialData: _queueService.getQueue(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _nextUp ??= snapshot.data!.nextUp;

            return SliverPadding(
              padding: const EdgeInsets.only(top: 0.0, left: 8.0, right: 8.0),
              sliver: SliverReorderableList(
                proxyDecorator: (widget, _, _) => Material(type: MaterialType.transparency, child: widget),
                autoScrollerVelocityScalar: 20.0,
                onReorder: (oldIndex, newIndex) {
                  int draggingOffset = oldIndex + 1;
                  int newPositionOffset = newIndex + 1;
                  if (mounted) {
                    FeedbackHelper.feedback(FeedbackType.heavy);
                    setState(() {
                      // temporarily update internal queue
                      FinampQueueItem tmp = _nextUp!.removeAt(oldIndex);
                      _nextUp!.insert(newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                      // update external queue to commit changes, results in a rebuild
                      _queueService.reorderByOffset(draggingOffset, newPositionOffset);
                    });
                  }
                },
                onReorderStart: (p0) {
                  FeedbackHelper.feedback(FeedbackType.selection);
                },
                findChildIndexCallback: (Key key) {
                  key = key as GlobalObjectKey;
                  final ValueKey<String> valueKey = key.value as ValueKey<String>;
                  final index = _nextUp!.indexWhere((item) => item.id == valueKey.value);
                  if (index == -1) return null;
                  return index;
                },
                itemCount: _nextUp?.length ?? 0,
                itemExtent: QueueListTile.height,
                itemBuilder: (context, index) {
                  final item = _nextUp![index];
                  final indexOffset = index + 1;
                  return QueueListTile(
                    key: ValueKey(item.id),
                    item: item.baseItem,
                    listIndex: index,
                    isInPlaylist: queueItemInPlaylist(item),
                    parentItem: item.source.item,
                    queueItem: item,
                    allowReorder: true,
                    onRemoveFromList: () {
                      unawaited(_queueService.removeAtOffset(indexOffset));
                    },
                    onTap: (bool playable) async {
                      FeedbackHelper.feedback(FeedbackType.selection);
                      await _queueService.skipByOffset(indexOffset);
                      scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
                    },
                    isCurrentTrack: false,
                  );
                },
              ),
            );
          } else {
            return SliverList(delegate: SliverChildListDelegate([]));
          }
        },
      ),
    );
  }
}

class QueueTracksList extends ConsumerStatefulWidget {
  final GlobalKey previousTracksHeaderKey;

  const QueueTracksList({super.key, required this.previousTracksHeaderKey});

  @override
  ConsumerState<QueueTracksList> createState() => _QueueTracksListState();
}

class _QueueTracksListState extends ConsumerState<QueueTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<FinampQueueItem>? _queue;
  List<FinampQueueItem>? _nextUp;

  @override
  Widget build(context) {
    return MenuMask(
      height: ref.watch(finampSettingsProvider.radioEnabled)
          ? QueueSectionHeader.radioActiveHeight
          : QueueSectionHeader.defaultHeight,
      child: StreamBuilder<FinampQueueInfo?>(
        stream: _queueService.getQueueStream(),
        initialData: _queueService.getQueue(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _queue ??= snapshot.data!.queue;
            _nextUp ??= snapshot.data!.nextUp;

            return SliverReorderableList(
              proxyDecorator: (widget, _, _) => Material(type: MaterialType.transparency, child: widget),
              autoScrollerVelocityScalar: 20.0,
              onReorder: (oldIndex, newIndex) {
                int draggingOffset = oldIndex + (_nextUp?.length ?? 0) + 1;
                int newPositionOffset = newIndex + (_nextUp?.length ?? 0) + 1;
                if (mounted) {
                  // update external queue to commit changes, but don't await it
                  _queueService.reorderByOffset(draggingOffset, newPositionOffset);
                  FeedbackHelper.feedback(FeedbackType.heavy);
                  setState(() {
                    // temporarily update internal queue
                    FinampQueueItem tmp = _queue!.removeAt(oldIndex);
                    _queue!.insert(newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                  });
                }
              },
              onReorderStart: (p0) {
                FeedbackHelper.feedback(FeedbackType.selection);
              },
              itemCount: _queue?.length ?? 0,
              findChildIndexCallback: (Key key) {
                key = key as GlobalObjectKey;
                final ValueKey<String> valueKey = key.value as ValueKey<String>;
                final index = _queue!.indexWhere((item) => item.id == valueKey.value);
                if (index == -1) return null;
                return index;
              },
              itemExtent: QueueListTile.height,
              itemBuilder: (context, index) {
                final item = _queue![index];
                final indexOffset = index + _nextUp!.length + 1;

                return QueueListTile(
                  key: ValueKey(item.id),
                  item: item.baseItem,
                  listIndex: index,
                  isInPlaylist: queueItemInPlaylist(item),
                  parentItem: item.source.item,
                  queueItem: item,
                  allowReorder: true,
                  onRemoveFromList: () {
                    unawaited(_queueService.removeAtOffset(indexOffset));
                  },
                  onTap: (bool playable) async {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    await _queueService.skipByOffset(indexOffset);
                    scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
                  },
                  isCurrentTrack: false,
                );
              },
            );
          } else {
            return SliverList(delegate: SliverChildListDelegate([]));
          }
        },
      ),
    );
  }
}

class CurrentTrack extends ConsumerStatefulWidget {
  const CurrentTrack({super.key});

  @override
  ConsumerState<CurrentTrack> createState() => _CurrentTrackState();
}

class _CurrentTrackState extends ConsumerState<CurrentTrack> {
  late QueueService _queueService;
  late MusicPlayerBackgroundTask _audioHandler;

  @override
  void initState() {
    super.initState();
    _queueService = GetIt.instance<QueueService>();
    _audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  }

  @override
  Widget build(context) {
    FinampQueueItem? currentTrack;
    MediaState? mediaState;
    Duration? playbackPosition;

    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

    return StreamBuilder<QueueListStreamState>(
      stream: Rx.combineLatest2<MediaState, FinampQueueInfo?, QueueListStreamState>(
        mediaStateStream,
        _queueService.getQueueStream(),
        (a, b) => QueueListStreamState(a, b),
      ),
      initialData: QueueListStreamState(
        MediaState(audioHandler.mediaItem.value, audioHandler.playbackState.value, audioHandler.fadeState.value),
        _queueService.getQueue(),
      ),
      builder: (context, snapshot) {
        var data = snapshot.data;
        currentTrack = data?.queueInfo?.currentTrack;
        if (data != null && currentTrack != null) {
          mediaState = data.mediaState;

          final currentTrackBaseItem = jellyfin_models.BaseItemDto.fromJson(
            currentTrack!.item.extras?["itemJson"] as Map<String, dynamic>,
          );

          const horizontalPadding = 8.0;
          const albumImageSize = 70.0;

          final elapsedPartBackgroundColor = ColorScheme.of(context).primary;
          final remainingPartBackgroundColor = Color.alphaBlend(
            elapsedPartBackgroundColor.withOpacity(0.7),
            // this is an approximation, the actual background has the blurred cover image
            ref.watch(brightnessProvider) == Brightness.dark ? Colors.black : Colors.white,
          );
          final averageBackgroundColor = Color.alphaBlend(
            elapsedPartBackgroundColor.withOpacity(0.5),
            remainingPartBackgroundColor,
          );
          Color primaryTextColor = AtContrast.getContrastiveTintedTextColor(onBackground: averageBackgroundColor);

          return SliverAppBar(
            pinned: true,
            collapsedHeight: 70.0,
            expandedHeight: 70.0,
            elevation: 10.0,
            leading: const Padding(padding: EdgeInsets.zero),
            forceMaterialTransparency: true,
            flexibleSpace: Container(
              // width: 58,
              height: albumImageSize,
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: remainingPartBackgroundColor,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (ref.watch(finampSettingsProvider.showProgressOnNowPlayingBar))
                          Positioned.fill(child: ColoredBox(color: IconTheme.of(context).color!.withOpacity(0.75))),
                        AlbumImage(borderRadius: BorderRadius.zero, imageListenable: currentAlbumImageProvider),
                        AudioFadeProgressVisualizerContainer(
                          key: const Key("AlbumArtAudioFadeProgressVisualizer"),
                          width: albumImageSize,
                          height: albumImageSize,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12.0),
                            bottomLeft: Radius.circular(12.0),
                          ),
                          color: Colors.white,
                          child: IconButton(
                            onPressed: () {
                              FeedbackHelper.feedback(FeedbackType.selection);
                              _audioHandler.togglePlayback();
                            },
                            icon: mediaState!.playbackState.playing
                                ? const Icon(TablerIcons.player_pause, size: 32)
                                : const Icon(TablerIcons.player_play, size: 32),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: StreamBuilder<Duration>(
                              stream: AudioService.position,
                              initialData: _audioHandler.playbackState.value.position,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  playbackPosition = snapshot.data;
                                  var itemLength = mediaState?.mediaItem?.duration;
                                  return FractionallySizedBox(
                                    alignment: AlignmentDirectional.centerStart,
                                    widthFactor: itemLength == null
                                        ? 0
                                        : max(0, playbackPosition!.inMilliseconds / itemLength.inMilliseconds),
                                    child: DecoratedBox(
                                      decoration: ShapeDecoration(
                                        color: elapsedPartBackgroundColor,
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
                                      SizedBox(
                                        height: 20,
                                        child: OneLineMarqueeHelper(
                                          key: ValueKey(currentTrack?.item.id),
                                          text: currentTrack?.item.title ?? AppLocalizations.of(context)!.unknownName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            height: 26 / 20,
                                            color: primaryTextColor,
                                            fontWeight: Theme.brightnessOf(context) == Brightness.light
                                                ? FontWeight.w500
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              processArtist(currentTrack!.item.artist, context),
                                              style: TextStyle(
                                                color: primaryTextColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              StreamBuilder<Duration>(
                                                stream: AudioService.position,
                                                initialData: _audioHandler.playbackState.value.position,
                                                builder: (context, snapshot) {
                                                  final TextStyle style = TextStyle(
                                                    color: primaryTextColor,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                  );
                                                  if (snapshot.hasData) {
                                                    playbackPosition = snapshot.data;
                                                    return Text(
                                                      // '0:00',
                                                      playbackPosition!.inHours >= 1.0
                                                          ? "${playbackPosition?.inHours.toString()}:${((playbackPosition?.inMinutes ?? 0) % 60).toString().padLeft(2, '0')}:${((playbackPosition?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}"
                                                          : "${playbackPosition?.inMinutes.toString()}:${((playbackPosition?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                                                      style: style,
                                                    );
                                                  } else {
                                                    return Text("0:00", style: style);
                                                  }
                                                },
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '/',
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                // '3:44',
                                                (mediaState?.mediaItem?.duration?.inHours ?? 0.0) >= 1.0
                                                    ? "${mediaState?.mediaItem?.duration?.inHours.toString()}:${((mediaState?.mediaItem?.duration?.inMinutes ?? 0) % 60).toString().padLeft(2, '0')}:${((mediaState?.mediaItem?.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}"
                                                    : "${mediaState?.mediaItem?.duration?.inMinutes.toString()}:${((mediaState?.mediaItem?.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: AddToPlaylistButton(
                                      item: currentTrackBaseItem,
                                      queueItem: currentTrack,
                                      color: primaryTextColor,
                                      size: 28,
                                      visualDensity: const VisualDensity(horizontal: -4),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: AppLocalizations.of(context)!.menuButtonLabel,
                                    iconSize: 28,
                                    visualDensity: const VisualDensity(horizontal: -4),
                                    // visualDensity: VisualDensity.compact,
                                    icon: Icon(TablerIcons.dots, size: 28, color: primaryTextColor, weight: 1.5),
                                    onPressed: () {
                                      FeedbackHelper.feedback(FeedbackType.selection);
                                      showModalTrackMenu(
                                        context: context,
                                        item: currentTrackBaseItem,
                                        parentItem: currentTrack?.source.item,
                                        confirmPlaylistRemoval: true,
                                        showQueueActions: true,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class PlaybackBehaviorInfo {
  final FinampPlaybackOrder order;
  final FinampLoopMode loop;
  final double speed;

  PlaybackBehaviorInfo(this.order, this.loop, this.speed);
}

class QueueSectionHeader extends ConsumerWidget {
  final Widget title;
  final QueueItemSource? source;
  final bool controls;
  final GlobalKey nextUpHeaderKey;
  final GlobalKey queueHeaderKey;
  final ScrollController scrollController;

  const QueueSectionHeader({
    super.key,
    required this.title,
    required this.source,
    required this.nextUpHeaderKey,
    required this.queueHeaderKey,
    required this.scrollController,
    this.controls = false,
  });

  static MenuMaskHeight defaultHeight = MenuMaskHeight(132.0);
  // queue header + radio chooser tile height
  static MenuMaskHeight radioActiveHeight = MenuMaskHeight(132.0 + 58.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    final radioEnabled = ref.watch(finampSettingsProvider.radioEnabled);
    final radioMode = ref.watch(finampSettingsProvider.radioMode);
    final radioSeedItem = ref.watch(getActiveRadioSeedProvider(radioMode));
    final currentRadioAvailabilityStatus = ref.watch(currentRadioAvailabilityStatusProvider);
    final radioLoading = ref.watch(radioStateProvider.select((state) => state?.loading ?? false));
    final radioFailed = ref.watch(radioStateProvider.select((state) => state?.failed ?? false));
    final radioModeTranslatedName = AppLocalizations.of(context)!.radioModeOptionName(radioMode.name);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, top: 12.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        StreamBuilder(
                          stream: queueService.getQueueStream(),
                          initialData: queueService.getQueue(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              var remaining = snapshot.data!.remainingDuration;
                              var remainText = printDuration(remaining, leadingZeroes: false);
                              final remainingLabelFullHours = (remaining.inHours);
                              final remainingLabelFullMinutes = (remaining.inMinutes) % 60;
                              final remainingLabelSeconds = (remaining.inSeconds) % 60;
                              final remainingLabelString =
                                  "${remainingLabelFullHours > 0 ? "$remainingLabelFullHours ${AppLocalizations.of(context)!.hours} " : ""}${remainingLabelFullMinutes > 0 ? "$remainingLabelFullMinutes ${AppLocalizations.of(context)!.minutes} " : ""}$remainingLabelSeconds ${AppLocalizations.of(context)!.seconds}";
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0, right: 8.0),
                                child: Text(
                                  "${snapshot.data!.currentTrackIndex} / ${snapshot.data!.trackCount}  (${AppLocalizations.of(context)!.remainingDuration(remainText)})",
                                  semanticsLabel:
                                      "${AppLocalizations.of(context)!.trackCountTooltip(snapshot.data!.currentTrackIndex, snapshot.data!.trackCount)} (${AppLocalizations.of(context)!.remainingDuration(remainingLabelString)})",
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    if (source != null) {
                      navigateToSource(context, source!);
                    }
                  },
                ),
              ),
              if (controls)
                StreamBuilder(
                  stream: Rx.combineLatest3(
                    queueService.getPlaybackOrderStream(),
                    queueService.getLoopModeStream(),
                    queueService.getPlaybackSpeedStream(),
                    (a, b, c) => PlaybackBehaviorInfo(a, b, c),
                  ),
                  initialData: PlaybackBehaviorInfo(
                    queueService.playbackOrder,
                    queueService.loopMode,
                    queueService.playbackSpeed,
                  ),
                  builder: (context, snapshot) {
                    PlaybackBehaviorInfo? info = snapshot.data;
                    return Row(
                      children: [
                        IconButtonWithSemantics(
                          label: info?.order == FinampPlaybackOrder.shuffled
                              ? AppLocalizations.of(context)!.playbackOrderShuffledButtonTooltip
                              : AppLocalizations.of(context)!.playbackOrderLinearButtonTooltip,
                          icon: info?.order == FinampPlaybackOrder.shuffled
                              ? (TablerIcons.arrows_shuffle)
                              : (TablerIcons.arrows_right),
                          iconSize: 28.0,
                          color: info?.order == FinampPlaybackOrder.shuffled
                              ? IconTheme.of(context).color!
                              : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white).withOpacity(0.85),
                          visualDensity: VisualDensity.standard,
                          onPressed: () async {
                            await queueService.togglePlaybackOrder();
                            FeedbackHelper.feedback(FeedbackType.selection);
                            if (queueService.getQueue().nextUp.isNotEmpty) {
                              scrollToKey(key: nextUpHeaderKey);
                            } else {
                              scrollToKey(key: queueHeaderKey);
                            }
                          },
                        ),
                        IconButtonWithSemantics(
                          label: radioEnabled
                              ? AppLocalizations.of(context)!.loopingUnavailableWhileRadioActiveWarning
                              : switch (info?.loop) {
                                  FinampLoopMode.none => AppLocalizations.of(context)!.loopModeNoneButtonLabel,
                                  FinampLoopMode.one => AppLocalizations.of(context)!.loopModeOneButtonLabel,
                                  FinampLoopMode.all => AppLocalizations.of(context)!.loopModeAllButtonLabel,
                                  null => AppLocalizations.of(context)!.loopModeNoneButtonLabel,
                                },
                          icon: switch (radioEnabled ? null : info?.loop) {
                            FinampLoopMode.none => TablerIcons.repeat_off,
                            FinampLoopMode.one => TablerIcons.repeat_once,
                            FinampLoopMode.all => TablerIcons.repeat,
                            null => TablerIcons.repeat_off,
                          },
                          iconSize: 28.0,
                          color: radioEnabled
                              ? (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white).withOpacity(0.3)
                              : (info?.loop != FinampLoopMode.none
                                    ? IconTheme.of(context).color!
                                    : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white).withOpacity(
                                        0.85,
                                      )),
                          visualDensity: VisualDensity.standard,
                          onPressed: () {
                            if (radioEnabled) {
                              GlobalSnackbar.message(
                                (scaffold) => AppLocalizations.of(context)!.loopingUnavailableWhileRadioActiveWarning,
                              );
                              return;
                            }
                            queueService.toggleLoopMode();
                            FeedbackHelper.feedback(FeedbackType.selection);
                          },
                          onLongPress: () => showRadioMenu(
                            context,
                            subtitle: AppLocalizations.of(context)!.loopingOverriddenByRadioSubtitle,
                          ),
                        ),
                        IconButtonWithSemantics(
                          label: radioEnabled
                              ? AppLocalizations.of(context)!.radioModeDisableButtonTitle
                              : AppLocalizations.of(context)!.radioModeEnableButtonTitle,
                          icon: radioEnabled ? TablerIcons.radio : TablerIcons.radio_off,
                          iconSize: 28.0,
                          color: currentRadioAvailabilityStatus.isAvailable
                              ? IconTheme.of(context).color!
                              : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white).withOpacity(0.85),
                          visualDensity: VisualDensity.standard,
                          onPressed: () {
                            toggleRadio();
                            FeedbackHelper.feedback(FeedbackType.selection);
                          },
                          onLongPress: () => showRadioMenu(context),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        // Radio mode
        if (radioEnabled)
          ChoiceMenuListTile(
            title: switch (currentRadioAvailabilityStatus) {
              RadioModeAvailabilityStatus.available => AppLocalizations.of(
                context,
              )!.radioModeOptionTitle(radioMode.name),
              RadioModeAvailabilityStatus.disabled => AppLocalizations.of(context)!.radioModeDisabledTitle,
              _ => AppLocalizations.of(context)!.radioModeInactiveTitle,
            },
            subtitle: switch (currentRadioAvailabilityStatus) {
              RadioModeAvailabilityStatus.available => AppLocalizations.of(context)!.radioModeEnabledSubtitle,
              RadioModeAvailabilityStatus.disabled => AppLocalizations.of(context)!.radioModeDisabledSubtitle,
              RadioModeAvailabilityStatus.unavailableSourceTypeNotSupported ||
              RadioModeAvailabilityStatus.unavailableSourceNull => AppLocalizations.of(
                context,
              )!.radioModeUnavailableForSourceItemSubtitle(radioModeTranslatedName),
              RadioModeAvailabilityStatus.unavailableOffline => AppLocalizations.of(
                context,
              )!.radioModeUnavailableWhileOfflineSubtitle(radioModeTranslatedName),
              RadioModeAvailabilityStatus.unavailableNotDownloaded =>
                radioSeedItem?.name != null
                    ? AppLocalizations.of(
                        context,
                      )!.radioModeRandomUnavailableNotDownloadedSubtitle(radioModeTranslatedName, radioSeedItem!.name!)
                    : AppLocalizations.of(
                        context,
                      )!.radioModeRandomUnavailableNotDownloadedGenericSubtitle(radioModeTranslatedName),
              RadioModeAvailabilityStatus.unavailableQueueEmpty => AppLocalizations.of(
                context,
              )!.radioModeUnavailableQueueEmptySubtitle(radioModeTranslatedName),
            },
            menuCreator: () => showRadioMenu(
              context,
              subtitle: radioFailed ? AppLocalizations.of(context)!.radioFailedSubtitle : null,
            ),
            isLoading: radioLoading,
            leading: Icon(
              !currentRadioAvailabilityStatus.isAvailable || radioFailed ? TablerIcons.radio_off : TablerIcons.radio,
              size: 32.0,
              color: currentRadioAvailabilityStatus.isAvailable ? IconTheme.of(context).color : null,
            ),
            state: currentRadioAvailabilityStatus.isAvailable,
            icon: radioFailed ? TablerIcons.alert_circle : getRadioModeIcon(radioMode),
            compact: true,
          ),
      ],
    );
  }
}

// TODO fix this being visible as it scrolls under currently playing track
class NextUpSectionHeader extends StatelessWidget {
  final bool controls;

  const NextUpSectionHeader({super.key, this.controls = false});

  static MenuMaskHeight defaultHeight = MenuMaskHeight(114.0);

  @override
  Widget build(context) {
    final queueService = GetIt.instance<QueueService>();

    return Container(
      // color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [Text(AppLocalizations.of(context)!.nextUp)],
            ),
          ),
          if (controls)
            SimpleButton(
              text: AppLocalizations.of(context)!.clearNextUp,
              icon: TablerIcons.x,
              iconPosition: IconPosition.end,
              iconSize: 32.0,
              iconColor: Theme.brightnessOf(context) == Brightness.light ? Colors.black : Colors.white,
              onPressed: () {
                queueService.clearNextUp();
                FeedbackHelper.feedback(FeedbackType.success);
              },
            ),
        ],
      ),
    );
  }
}

class PreviousTracksSectionHeader extends SliverPersistentHeaderDelegate {
  // final bool controls;
  final double height;
  final VoidCallback? onTap;
  final GlobalKey previousTracksHeaderKey;

  PreviousTracksSectionHeader({
    required this.previousTracksHeaderKey,
    // this.controls = false,
    this.onTap,
    this.height = 50.0,
  });

  @override
  Widget build(context, double shrinkOffset, bool overlapsContent) {
    return Padding(
      padding: const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 12.0, top: 8.0),
      child: GestureDetector(
        onTap: () {
          try {
            if (onTap != null) {
              onTap!();
              FeedbackHelper.feedback(FeedbackType.selection);
            }
          } catch (e) {
            FeedbackHelper.feedback(FeedbackType.error);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(AppLocalizations.of(context)!.previousTracks),
            ),
            const SizedBox(width: 4.0),
            Consumer(
              builder: (context, ref, child) {
                final isExpanded = ref.watch(finampSettingsProvider.previousTracksExpanded);
                return Icon(
                  isExpanded ? TablerIcons.chevron_up : TablerIcons.chevron_down,
                  size: 28.0,
                  color: Theme.brightnessOf(context) == Brightness.light ? Colors.black : Colors.white,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;
}
