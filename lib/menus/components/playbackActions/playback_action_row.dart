import 'package:finamp/menus/components/playbackActions/playback_action_page_indicator.dart';
import 'package:finamp/menus/components/playbackActions/playback_actions.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final double playActionRowHeightDefault = 96.0;
final double playActionPageIndicatorHeightDefault = 31.0;

class PlaybackActionRow extends ConsumerStatefulWidget {
  const PlaybackActionRow({
    super.key,
    required this.item,
    this.popContext = true,
    this.compactLayout = false,
    this.queueItem,
  });

  final FinampPlayable item;
  final bool popContext;
  final bool compactLayout;
  final FinampQueueItem? queueItem;

  @override
  ConsumerState<PlaybackActionRow> createState() => _PlaybackActionRowState();
}

class _PlaybackActionRowState extends ConsumerState<PlaybackActionRow> {
  late PageController controller;

  @override
  Widget build(BuildContext context) {
    final nextUpEmpty = ref.watch(QueueService.queueProvider)?.nextUp.isEmpty ?? true;
    final preferPreprendingToNextUp = ref.watch(finampSettingsProvider.preferNextUpPrepending);

    final Map<PlaybackActionRowPage, Widget> playbackActionPages = getPlaybackActionPages(
      context: context,
      item: widget.item,
      nextUpNotEmpty: !nextUpEmpty,
      popContext: widget.popContext,
      compactLayout: widget.compactLayout,
      preferPrependingToNextUp: ref.watch(finampSettingsProvider.preferNextUpPrepending),
      queueItem: widget.queueItem,
    );

    // initial page for regular playback action row
    // queue menu pages are saved as a separate setting from others.
    var lastUsedPlaybackActionRowPage = widget.queueItem != null
        ? ref.watch(finampSettingsProvider.lastUsedPlaybackActionRowPageForQueueMenu)
        : ref.watch(finampSettingsProvider.lastUsedPlaybackActionRowPage);
    lastUsedPlaybackActionRowPage =
        nextUpEmpty && preferPreprendingToNextUp && lastUsedPlaybackActionRowPage == PlaybackActionRowPage.appendNext
        ? PlaybackActionRowPage.playNext
        : lastUsedPlaybackActionRowPage;
    final lastUsedPlaybackActionRowPageIndex = playbackActionPages.keys.toList().indexOf(lastUsedPlaybackActionRowPage);
    final initialPageViewIndex = ref.watch(finampSettingsProvider.rememberLastUsedPlaybackActionRowPage)
        ? lastUsedPlaybackActionRowPageIndex
        : 0;
    controller = PageController(initialPage: initialPageViewIndex.clamp(0, playbackActionPages.length));
    final double playActionRowHeight = widget.compactLayout ? 76.0 : playActionRowHeightDefault;
    final rememberLastUsedPlaybackActionRowPage = ref.read(
      finampSettingsProvider.rememberLastUsedPlaybackActionRowPage,
    );

    return Column(
      verticalDirection: VerticalDirection.up,
      children: [
        SizedBox(
          height: playActionRowHeight,
          child: PageView(
            controller: controller,
            // animation speed can't be changed directly, so we use a custom ScrollPhysics (source: https://stackoverflow.com/questions/65325496/flutter-pageview-how-to-make-faster-animations-on-swipe)
            physics: const FasterPageViewScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            allowImplicitScrolling: true,
            scrollDirection: Axis.horizontal,
            children: playbackActionPages.values.toList(),
            onPageChanged: (index) {
              if (!rememberLastUsedPlaybackActionRowPage || playbackActionPages.keys.length <= 1) return;

              final newPage = playbackActionPages.keys.toList()[index];
              if (widget.queueItem != null) {
                FinampSetters.setLastUsedPlaybackActionRowPageForQueueMenu(newPage);
              } else {
                FinampSetters.setLastUsedPlaybackActionRowPage(newPage);
              }
            },
          ),
        ),
        if (playbackActionPages.keys.length > 1)
          PlaybackActionPageIndicator(
            pages: playbackActionPages,
            pageController: controller,
            compactLayout: widget.compactLayout,
          ),
      ],
    );
  }
}

class FasterPageViewScrollPhysics extends ScrollPhysics {
  const FasterPageViewScrollPhysics({required ScrollPhysics super.parent});

  @override
  SpringDescription get spring {
    return const SpringDescription(mass: 40, stiffness: 100, damping: 1);
  }
}
