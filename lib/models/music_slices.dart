//
//
//  Public slice classes to return
//
//

import 'dart:math';

import '../extensions/list.dart';
import '../services/item_helper.dart';
import 'finamp_models.dart';
import 'jellyfin_models.dart';

sealed class PlayableSlice {
  PlayableSlice({required this.source, required this.shuffleState});
  final QueueItemSource source;
  final SliceShuffleState shuffleState;

  PlayableSlice shuffle();
  PlayableSlice markPreshuffled();

  factory PlayableSlice.simple(List<BaseItemDto> items, QueueItemSource source) =>
      BasePlayableSlice(items: items, startingIndex: 0, source: source, shuffleState: SliceShuffleState.linear);

  Future<BasePlayableSlice> resolve({bool preShuffle = false});
}

final class BasePlayableSlice extends PlayableSlice {
  BasePlayableSlice({
    required this.items,
    required this.startingIndex,
    required super.source,
    required super.shuffleState,
  }) : assert(items.every((x) => BaseItemDtoType.fromItem(x) == BaseItemDtoType.track)),
       assert(shuffleState != SliceShuffleState.preShuffled || startingIndex == 0);

  final List<BaseItemDto> items;
  final int startingIndex;

  @override
  BasePlayableSlice shuffle() {
    return BasePlayableSlice(
      items: items,
      startingIndex: startingIndex,
      source: source,
      shuffleState: shuffleState == SliceShuffleState.linear ? SliceShuffleState.playerShuffled : shuffleState,
    );
  }

  BasePlayableSlice fromIndex(int newIndex, {int? limit}) {
    newIndex = newIndex.clamp(0, max(0, items.length - 1));
    if (limit == null) {
      return BasePlayableSlice(items: items, startingIndex: newIndex, source: source, shuffleState: shuffleState);
    }

    final excess = limit - (items.length - newIndex);
    final preTracks = excess.clamp(0, newIndex);

    return BasePlayableSlice(
      items: items.safeSliceByLength(newIndex - preTracks, min(newIndex + limit, items.length)),
      startingIndex: preTracks,
      source: source,
      shuffleState: shuffleState,
    );
  }

  @override
  Future<BasePlayableSlice> resolve({bool preShuffle = false}) async {
    switch (this) {
      case BasePlayableSlice base:
        if (switch (base.shuffleState) {
              SliceShuffleState.preShuffled => false,
              SliceShuffleState.playerShuffled => true,
              SliceShuffleState.linear => false,
            } &&
            preShuffle) {
          List<BaseItemDto> clonedItems = List.from(base.items);
          clonedItems.shuffle();
          return BasePlayableSlice(
            items: clonedItems,
            startingIndex: 0,
            source: source,
            shuffleState: SliceShuffleState.preShuffled,
          );
        }
        return this;
    }
  }

  @override
  PlayableSlice markPreshuffled() {
    return BasePlayableSlice(
      items: items,
      startingIndex: startingIndex,
      source: source,
      shuffleState: SliceShuffleState.preShuffled,
    );
  }
}

final class GroupedPlayableSlice extends PlayableSlice {
  GroupedPlayableSlice({required this.parent, required this.groupBy})
    : super(source: parent.source, shuffleState: SliceShuffleState.preShuffled);
  final PlayableSlice parent;
  final String? Function(BaseItemDto) groupBy;

  @override
  Future<BasePlayableSlice> resolve({bool preShuffle = false}) async {
    final resolvedParent = await parent.resolve(preShuffle: preShuffle);
    final items = groupItems(
      items: resolvedParent.items,
      groupListBy: (element) => element.albumId?.toString(),
      manuallyShuffle: true,
    );
    return BasePlayableSlice(
      items: items,
      // We can't match the old starting item, so just start at 0
      startingIndex: 0,
      source: source,
      shuffleState: shuffleState,
    );
  }

  @override
  PlayableSlice shuffle() => this;
  @override
  PlayableSlice markPreshuffled() => this;
}

class PreCachedPlayableSlice extends PlayableSlice {
  PreCachedPlayableSlice({
    required super.source,
    required super.shuffleState,
    required this.cachedTracks,
    required this.fetchTracks,
    required this.combineTracks,
    required this.startingOffset,
  }) : assert(startingOffset < cachedTracks.length);

  final List<BaseItemDto> cachedTracks;
  final Future<List<BaseItemDto>> fetchTracks;
  final bool combineTracks;
  int startingOffset;

  @override
  PlayableSlice markPreshuffled() => PreCachedPlayableSlice(
    source: source,
    shuffleState: SliceShuffleState.preShuffled,
    cachedTracks: cachedTracks,
    fetchTracks: fetchTracks,
    combineTracks: combineTracks,
    startingOffset: startingOffset,
  );

  @override
  Future<BasePlayableSlice> resolve({bool preShuffle = false}) async {
    final fetchedTracks = await fetchTracks;
    List<BaseItemDto> items;
    if (combineTracks) {
      items = cachedTracks + fetchedTracks;
    } else {
      assert(() {
        for (int i = 0; i < cachedTracks.length; i++) {
          if (cachedTracks[i] != fetchedTracks[i]) {
            return false;
          }
        }
        return true;
      }());
      items = fetchedTracks;
    }
    return BasePlayableSlice(
      items: items,
      startingIndex: 0,
      source: source,
      shuffleState: shuffleState,
    ).resolve(preShuffle: preShuffle);
  }

  @override
  PlayableSlice shuffle() => PreCachedPlayableSlice(
    source: source,
    shuffleState: shuffleState == SliceShuffleState.linear ? SliceShuffleState.playerShuffled : shuffleState,
    cachedTracks: cachedTracks,
    fetchTracks: fetchTracks,
    combineTracks: combineTracks,
    startingOffset: startingOffset,
  );
}

// TODO add class extends PlayableSlice with a shuffle order for player already prepared to allow passing queues around easily?

enum SliceShuffleState { preShuffled, playerShuffled, linear }
