import 'dart:async';

import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/playbackActions/playback_action.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

import '../../../models/music_slices.dart';
import '../../../services/music_providers.dart';

Map<PlaybackActionRowPage, Widget> getPlaybackActionPages({
  required BuildContext context,
  required FinampPlayable item,
  required bool nextUpNotEmpty,
  bool popContext = true,
  bool compactLayout = false,
  bool preferPrependingToNextUp = false,
  FinampQueueItem? queueItem,
}) {
  final BaseItemDtoType? itemType = item is FinampPlayableDto ? BaseItemDtoType.fromItem(item.item) : null;
  final canShuffleAlbums =
      itemType == BaseItemDtoType.artist || itemType == BaseItemDtoType.genre || item is FinampDisplayable<Album>;

  if (itemType == BaseItemDtoType.track) {
    return {
      if (queueItem != null)
        // Move within queue
        PlaybackActionRowPage.moveWithinQueue: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (nextUpNotEmpty || preferPrependingToNextUp)
              MovePlayNextPlaybackAction(item: queueItem, popContext: popContext, compactLayout: compactLayout),
            if (nextUpNotEmpty || !preferPrependingToNextUp)
              MoveAddToNextUpPlaybackAction(item: queueItem, popContext: popContext, compactLayout: compactLayout),
            MoveAddToQueuePlaybackAction(item: queueItem, popContext: popContext, compactLayout: compactLayout),
          ],
        ),
      // Regular Options
      PlaybackActionRowPage.regularTrackOptions: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PlayPlaybackAction(item: item),
          if (nextUpNotEmpty || preferPrependingToNextUp) PlayNextPlaybackAction(item: item),
          if (nextUpNotEmpty || !preferPrependingToNextUp) AddToNextUpPlaybackAction(item: item),
          AddToQueuePlaybackAction(item: item),
        ],
      ),
    };
  } else {
    return {
      // New Queue
      PlaybackActionRowPage.newQueue: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (itemType != BaseItemDtoType.genre)
            PlayPlaybackAction(item: item, popContext: popContext, compactLayout: compactLayout),
          ShufflePlaybackAction(item: item, itemType: itemType, popContext: popContext, compactLayout: compactLayout),
          if (canShuffleAlbums)
            ShuffleAlbumsPlaybackAction(
              item: item,
              itemType: itemType,
              popContext: popContext,
              compactLayout: compactLayout,
            ),
        ],
      ),
      // Next
      if (nextUpNotEmpty || preferPrependingToNextUp)
        PlaybackActionRowPage.playNext: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (itemType != BaseItemDtoType.genre)
              PlayNextPlaybackAction(item: item, popContext: popContext, compactLayout: compactLayout),
            ShuffleNextPlaybackAction(
              item: item,
              itemType: itemType,
              popContext: popContext,
              compactLayout: compactLayout,
            ),
            if (canShuffleAlbums)
              ShuffleAlbumsNextPlaybackAction(
                item: item,
                itemType: itemType,
                popContext: popContext,
                compactLayout: compactLayout,
              ),
          ],
        ),
      // Append to Next Up
      if (nextUpNotEmpty || !preferPrependingToNextUp)
        PlaybackActionRowPage.appendNext: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (itemType != BaseItemDtoType.genre)
              AddToNextUpPlaybackAction(item: item, popContext: popContext, compactLayout: compactLayout),
            ShuffleToNextUpPlaybackAction(
              item: item,
              itemType: itemType,
              popContext: popContext,
              compactLayout: compactLayout,
            ),
            if (canShuffleAlbums)
              ShuffleAlbumsToNextUpPlaybackAction(
                item: item,
                itemType: itemType,
                popContext: popContext,
                compactLayout: compactLayout,
              ),
          ],
        ),
      // Append to Queue
      PlaybackActionRowPage.playLast: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (itemType != BaseItemDtoType.genre)
            AddToQueuePlaybackAction(item: item, popContext: popContext, compactLayout: compactLayout),
          ShuffleToQueuePlaybackAction(
            item: item,
            itemType: itemType,
            popContext: popContext,
            compactLayout: compactLayout,
          ),
          if (canShuffleAlbums)
            ShuffleAlbumsToQueuePlaybackAction(
              item: item,
              itemType: itemType,
              popContext: popContext,
              compactLayout: compactLayout,
            ),
        ],
      ),
    };
  }
}

class PlayPlaybackAction extends ConsumerWidget {
  const PlayPlaybackAction({super.key, required this.item, this.popContext = true, this.compactLayout = false});

  final FinampPlayable item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    return PlaybackAction(
      icon: TablerIcons.player_play,
      label: AppLocalizations.of(context)!.playButtonLabel,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.startSlicePlayback(
          await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future),
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class PlayNextPlaybackAction extends ConsumerWidget {
  const PlayNextPlaybackAction({super.key, required this.item, this.popContext = true, this.compactLayout = false});

  final FinampPlayable item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.corner_right_down,
      label: AppLocalizations.of(context)!.playNext,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addNext(await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future));

        GlobalSnackbar.message(
          (scaffold) =>
              AppLocalizations.of(scaffold)!.confirmPlayNext(BaseItemDtoType.fromPlayableItem(item)?.name ?? ""),
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class MovePlayNextPlaybackAction extends ConsumerWidget {
  const MovePlayNextPlaybackAction({super.key, required this.item, this.popContext = true, this.compactLayout = false});

  final FinampQueueItem item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.corner_right_down,
      label: AppLocalizations.of(context)!.movePlayNext,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        unawaited(queueService.removeQueueItem(item));
        await queueService.addNext(PlayableSlice.simple([item.baseItem], item.source));

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmPlayNext(BaseItemDtoType.fromItem(item.baseItem).name),
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class AddToNextUpPlaybackAction extends ConsumerWidget {
  const AddToNextUpPlaybackAction({super.key, required this.item, this.popContext = true, this.compactLayout = false});

  final FinampPlayable item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.corner_right_down_double,
      label: AppLocalizations.of(context)!.addToNextUp,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addToNextUp(await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future));

        GlobalSnackbar.message(
          (scaffold) =>
              AppLocalizations.of(scaffold)!.confirmAddToNextUp(BaseItemDtoType.fromPlayableItem(item)?.name ?? ""),
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class MoveAddToNextUpPlaybackAction extends ConsumerWidget {
  const MoveAddToNextUpPlaybackAction({
    super.key,
    required this.item,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampQueueItem item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.corner_right_down_double,
      label: AppLocalizations.of(context)!.moveAddToNextUp,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        unawaited(queueService.removeQueueItem(item));
        await queueService.addToNextUp(PlayableSlice.simple([item.baseItem], item.source));

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmAddToNextUp(BaseItemDtoType.fromItem(item.baseItem).name),
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class AddToQueuePlaybackAction extends ConsumerWidget {
  const AddToQueuePlaybackAction({super.key, required this.item, this.popContext = true, this.compactLayout = false});

  final FinampPlayable item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.playlist,
      label: AppLocalizations.of(context)!.addToQueue,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addToQueue(await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future));

        GlobalSnackbar.message(
          (scaffold) =>
              AppLocalizations.of(scaffold)!.confirmAddToQueue(BaseItemDtoType.fromPlayableItem(item)?.name ?? ""),
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class MoveAddToQueuePlaybackAction extends ConsumerWidget {
  const MoveAddToQueuePlaybackAction({
    super.key,
    required this.item,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampQueueItem item;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.playlist,
      label: AppLocalizations.of(context)!.moveAddToQueue,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        unawaited(queueService.removeQueueItem(item));
        await queueService.addToQueue(PlayableSlice.simple([item.baseItem], item.source));

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmAddToQueue(BaseItemDtoType.fromItem(item.baseItem).name),
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShufflePlaybackAction extends ConsumerWidget {
  const ShufflePlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.arrows_shuffle,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSome
          : AppLocalizations.of(context)!.shuffleButtonLabel,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.startSlicePlayback(
          (await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future)).shuffle(),
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleNextPlaybackAction extends ConsumerWidget {
  const ShuffleNextPlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.corner_right_down,
      addShuffleIcon: true,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeNext
          : AppLocalizations.of(context)!.shuffleNext,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addNext(
          (await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future)).shuffle(),
        );

        GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.confirmShuffleNext, isConfirmation: true);
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleToNextUpPlaybackAction extends ConsumerWidget {
  const ShuffleToNextUpPlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.corner_right_down_double,
      addShuffleIcon: true,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeToNextUp
          : AppLocalizations.of(context)!.shuffleToNextUp,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addToNextUp(
          (await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future)).shuffle(),
        );

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmShuffleToNextUp,
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleToQueuePlaybackAction extends ConsumerWidget {
  const ShuffleToQueuePlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();

    return PlaybackAction(
      icon: TablerIcons.playlist,
      addShuffleIcon: true,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeToQueue
          : AppLocalizations.of(context)!.shuffleToQueue,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addToQueue(
          (await ref.watch(getPlayerSliceProvider(item: item, startingOffset: 0).future)).shuffle(),
        );

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmShuffleToQueue,
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleAlbumsPlaybackAction extends ConsumerWidget {
  const ShuffleAlbumsPlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    assert(item is Genre || item is Artist || (item is FinampSortable<Album> && item is FinampPlayable));

    return PlaybackAction(
      icon: TablerIcons.arrows_shuffle,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeAlbums
          : AppLocalizations.of(context)!.shuffleAlbums,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.startSlicePlayback(await ref.watch(getAlbumShuffledPlayerSliceProvider(item: item).future));
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleAlbumsNextPlaybackAction extends ConsumerWidget {
  const ShuffleAlbumsNextPlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    assert(item is Genre || item is Artist || (item is FinampSortable<Album> && item is FinampPlayable));

    return PlaybackAction(
      icon: TablerIcons.corner_right_down,
      addShuffleIcon: true,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeAlbumsNext
          : AppLocalizations.of(context)!.shuffleAlbumsNext,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addNext(await ref.watch(getAlbumShuffledPlayerSliceProvider(item: item).future));

        GlobalSnackbar.message((scaffold) => AppLocalizations.of(scaffold)!.confirmShuffleNext, isConfirmation: true);
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleAlbumsToNextUpPlaybackAction extends ConsumerWidget {
  const ShuffleAlbumsToNextUpPlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    assert(item is Genre || item is Artist || (item is FinampSortable<Album> && item is FinampPlayable));

    return PlaybackAction(
      icon: TablerIcons.corner_right_down_double,
      addShuffleIcon: true,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeAlbumsToNextUp
          : AppLocalizations.of(context)!.shuffleAlbumsToNextUp,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addToNextUp(await ref.watch(getAlbumShuffledPlayerSliceProvider(item: item).future));

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmShuffleToNextUp,
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}

class ShuffleAlbumsToQueuePlaybackAction extends ConsumerWidget {
  const ShuffleAlbumsToQueuePlaybackAction({
    super.key,
    required this.item,
    this.itemType,
    this.popContext = true,
    this.compactLayout = false,
  });

  final FinampPlayable item;
  final BaseItemDtoType? itemType;
  final bool popContext;
  final bool compactLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueService = GetIt.instance<QueueService>();
    assert(item is Genre || item is Artist || (item is FinampSortable<Album> && item is FinampPlayable));

    return PlaybackAction(
      icon: TablerIcons.playlist,
      addShuffleIcon: true,
      label: (itemType == BaseItemDtoType.genre)
          ? AppLocalizations.of(context)!.shuffleSomeAlbumsToQueue
          : AppLocalizations.of(context)!.shuffleAlbumsToQueue,
      compactLayout: compactLayout,
      onPressed: () async {
        if (popContext) {
          Navigator.pop(context);
        }

        await queueService.addToQueue(await ref.watch(getAlbumShuffledPlayerSliceProvider(item: item).future));

        GlobalSnackbar.message(
          (scaffold) => AppLocalizations.of(scaffold)!.confirmShuffleToQueue,
          isConfirmation: true,
        );
      },
      iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
    );
  }
}
