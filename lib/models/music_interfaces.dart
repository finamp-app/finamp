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

  int get normalChildSize;
}

sealed class FinampPlayableDto extends FinampPlayable {
  FinampPlayableDto(this.item, {QueueItemSource? source}) : super(source: source ?? QueueItemSource.fromBaseItem(item));

  final BaseItemDto item;

  @override
  String get id => item.id.raw;

  factory FinampPlayableDto.fromItem(BaseItemDto item, {QueueItemSource? source, ResolvedSortConfig? sortOverride}) {
    return switch (BaseItemDtoType.fromItem(item)) {
      BaseItemDtoType.album => Album(item, source: source),
      BaseItemDtoType.playlist => Playlist(
        item,
        source: source,
        sortConfig: sortOverride ?? SortAndFilterConfiguration.defaultInAlbumSort,
      ),
      BaseItemDtoType.artist => Artist(
        item,
        source: source,
        sortConfig: SortAndFilterConfiguration.defaultSort,
        type: ArtistChildType.tracks,
        library: currentLibraryPlaceholder,
      ),
      BaseItemDtoType.genre => Genre(
        item,
        source: source,
        sortConfig: SortAndFilterConfiguration.defaultSort,
        type: GenreChildType.tracks,
        library: currentLibraryPlaceholder,
      ),
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
//   Private classes to ease implementations
//
//

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

sealed class _SortablePagedItem<ChildType extends FinampPlayableDto> extends FinampPlayableDto
    implements FinampSortable<ChildType>, FinampPagedPlayable<ChildType> {
  _SortablePagedItem(super.item, {required super.source, required this.sortConfig})
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
    return other is _SortablePagedItem && sortConfig == other.sortConfig && super.equalsHelperChain(other);
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
  bool operator ==(Object other) {
    assert(_validateEquals());
    return equalsHelper(other) && equalsHelperChain(other);
  }

  @override
  int get hashCode => Object.hash(hashHelper, hashHelperChain);

  bool equalsHelper(Object other);
  int get hashHelper;

  @mustCallSuper
  bool equalsHelperChain(Object other) => true;

  @mustCallSuper
  int get hashHelperChain => 0;

  // Bad equals methods that return false when they shouldn't can lead to the providers loading indefinitely without errors
  // This method double checks the subclasses equals method to help prevent that.
  bool _validateEquals() {
    final item = this as FinampDisplayableOrPlayable;
    FinampDisplayableOrPlayable copy;
    switch (item) {
      case FinampSortable sortable:
        copy = sortable.copyWith(sortable.sortConfig);
      case PlayableQueue queue:
        copy = PlayableQueue(queue: queue.queue, source: queue.source);
      case Album album:
        copy = Album(album.item, source: album.source);
      case AlbumDisc disc:
        copy = AlbumDisc(disc.item, tracks: disc.tracks);
      case PrecalculatedPlayable precalc:
        copy = PrecalculatedPlayable(source: precalc.source, tracks: precalc.tracks);
      case Track track:
        copy = Track(track.item, source: track.source);
      case InstantMix mix:
        copy = InstantMix(mix.item);
      case UnavailableHomeSectionPlayable item:
        copy = UnavailableHomeSectionPlayable(source: item.source, section: item.section);
    }
    return equalsHelper(copy) && equalsHelperChain(copy) && hashCode == copy.hashCode && !identical(item, copy);
  }
}

extension PlayableHelpers on FinampDisplayableOrPlayable {
  BaseItemDto? get maybeItem => this is FinampPlayableDto ? (this as FinampPlayableDto).item : null;
  bool get canShuffleAlbums => this is Genre || this is Artist || this is FinampDisplayable<Album>;
}
