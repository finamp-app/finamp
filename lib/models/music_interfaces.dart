// Concrete instances are in a separate file, but must be included in this library so that the sealed classes work
part of 'music_models.dart';

//
//
//   Core public interfaces
//
//

// TODO better documentation

sealed class FinampDisplayableOrPlayable {
  const FinampDisplayableOrPlayable({required this.source});
  String get id;
  final QueueItemSource source;
}

sealed class FinampDisplayable<ChildType extends FinampDisplayableOrPlayable> extends FinampDisplayableOrPlayable
    with _NeedsEquals {
  const FinampDisplayable({required super.source});
}

sealed class FinampPlayable extends FinampDisplayableOrPlayable with _NeedsEquals {
  const FinampPlayable({required super.source});
}

sealed class FinampUnpagedPlayable<ChildType extends FinampPlayable> extends FinampPlayable
    implements FinampUnpagedDisplayable<ChildType> {
  const FinampUnpagedPlayable({required super.source});
}

sealed class FinampUnpagedDisplayable<ChildType extends FinampDisplayableOrPlayable>
    extends FinampDisplayable<ChildType> {
  const FinampUnpagedDisplayable({required super.source});
}

sealed class FinampPagedPlayable<ChildType extends FinampPlayable> extends FinampPlayable
    implements FinampDisplayable<ChildType> {
  const FinampPagedPlayable({required super.source});
}

sealed class FinampPlayableDto extends FinampPlayable {
  const FinampPlayableDto(this.item, {required super.source});

  final BaseItemDto item;

  @override
  String get id => item.id.raw;

  factory FinampPlayableDto.fromItem(BaseItemDto item, {QueueItemSource? source, ResolvedSortConfig? sortOverride}) {
    source ??= QueueItemSource.fromBaseItem(item);
    return switch (BaseItemDtoType.fromItem(item)) {
      BaseItemDtoType.album => Album(item, source: source),
      BaseItemDtoType.playlist => Playlist(
        item,
        source: source,
        sortConfig: sortOverride ?? SortAndFilterConfiguration.defaultInAlbumSort,
      ),
      BaseItemDtoType.artist => GenericPlayableItem.defaultSort(item),
      BaseItemDtoType.genre => GenericPlayableItem.defaultSort(item),
      BaseItemDtoType.track => Track(item, source: source),
      BaseItemDtoType.collection => JellyfinCollection(
        item,
        source: source,
        sortConfig: sortOverride ?? SortAndFilterConfiguration.defaultSort,
      ),
      _ => throw UnsupportedError("Unexpected BaseItemDto type: ${item.type}"),
    };
  }

  @override
  bool equalsHelperChain(Object other) {
    return other is FinampPlayableDto && item == other.item && super.equalsHelperChain(other);
  }

  @override
  int get hashHelperChain => Object.hash(item, super.hashHelperChain);
}

sealed class FinampSortable<ChildType extends FinampDisplayableOrPlayable> extends FinampDisplayable<ChildType> {
  const FinampSortable({required this.sortConfig, required super.source});

  final ResolvedSortConfig sortConfig;

  // TODO consider some sort of isValid method to make sure the incoming config makes sense?
  FinampSortable copyWith(ResolvedSortConfig newSort);
}

//
//
//  Public slice classes to return
//
//

final class PlayableSlice {
  PlayableSlice({required this.items, required this.startingIndex, required this.source, required this.shuffleState})
    : assert(items.every((x) => BaseItemDtoType.fromItem(x) == BaseItemDtoType.track));

  final List<BaseItemDto> items;
  final int startingIndex;
  final QueueItemSource source;
  final SliceShuffleState shuffleState;

  PlayableSlice shuffle() {
    return PlayableSlice(
      items: items,
      startingIndex: 0,
      source: source,
      shuffleState: shuffleState == SliceShuffleState.linear ? SliceShuffleState.playerShuffled : shuffleState,
    );
  }

  // TODO is this useful?
  PlayableSlice preShuffle() {
    final clonedItems = List<BaseItemDto>.from(items);
    clonedItems.shuffle();
    return PlayableSlice(
      items: clonedItems,
      startingIndex: 0,
      source: source,
      shuffleState: SliceShuffleState.preShuffled,
    );
  }

  PlayableSlice fromIndex(int newIndex, {int? limit}) {
    newIndex = newIndex.clamp(0, max(0, items.length - 1));
    if (limit == null) {
      return PlayableSlice(items: items, startingIndex: newIndex, source: source, shuffleState: shuffleState);
    }

    final excess = limit - (items.length - newIndex);
    final preTracks = excess.clamp(0, newIndex);

    return PlayableSlice(
      items: items.safeSliceByLength(newIndex - preTracks, min(newIndex + limit, items.length)),
      startingIndex: preTracks,
      source: source,
      shuffleState: shuffleState,
    );
  }
}

// TODO add class extends PlayableSlice with a shuffle order for player already prepared to allow passing queues around easily?

enum SliceShuffleState { preShuffled, playerShuffled, linear }

//
//
//   Private classes to ease implementations
//
//

// As of right now, we do not apply paging for any item types, only the music screens.
sealed class _SortableItem<ChildType extends FinampPlayableDto> extends FinampPlayableDto
    implements FinampSortable<ChildType>, FinampUnpagedDisplayable<ChildType>, FinampUnpagedPlayable<ChildType> {
  _SortableItem(super.item, {required super.source, required this.sortConfig})
    : assert(() {
        ContentType type = [BaseItemDtoType.album, BaseItemDtoType.playlist].contains(BaseItemDtoType.fromItem(item))
            ? ContentType.inPlaylist
            : ContentType.tracks;
        final controller = SortAndFilterController(startingConfig: sortConfig, contentType: type);
        final resolvedConfig = GetIt.instance<ProviderContainer>().read(resolveSortProvider(controller));
        return sortConfig == resolvedConfig;
      }());

  @override
  final ResolvedSortConfig sortConfig;

  @override
  bool equalsHelperChain(Object other) {
    return other is _SortableItem && sortConfig == other.sortConfig && super.equalsHelperChain(other);
  }

  @override
  int get hashHelperChain => Object.hash(sortConfig, super.hashHelperChain);
}

sealed class _SortablePagedPlayable<ChildType extends FinampPlayable> extends FinampPagedPlayable<ChildType>
    implements FinampSortable<ChildType> {
  _SortablePagedPlayable({required super.source, required this.sortConfig});

  @override
  final ResolvedSortConfig sortConfig;

  @override
  bool equalsHelperChain(Object other) {
    return other is _SortablePagedPlayable && sortConfig == other.sortConfig && super.equalsHelperChain(other);
  }

  @override
  int get hashHelperChain => Object.hash(sortConfig, super.hashHelperChain);
}

/// This mixin forces all the final implementation classes to implement [equalsHelper] and [hashHelper] so that providers
/// work properly.  All implementations of [equalsHelper] and [hashHelper] should call [equalsHelperChain] and [hashHelperChain]
/// to make sure that all variables in the superclasses are included.
mixin _NeedsEquals {
  @override
  bool operator ==(Object other) => equalsHelper(other) && equalsHelperChain(other);

  @override
  int get hashCode => Object.hash(hashHelper, hashHelperChain);

  bool equalsHelper(Object other);
  int get hashHelper;

  @mustCallSuper
  bool equalsHelperChain(Object other) => true;

  @mustCallSuper
  int get hashHelperChain => 0;
}
