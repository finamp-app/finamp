import 'package:finamp/components/MusicScreen/item_wrapper.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectionsSliverList extends ConsumerWidget {
  const CollectionsSliverList({
    super.key,
    required this.childrenForList,
    required this.parent,
    this.genreFilter,
    this.albumShowsYearAndDurationInstead = false,
    this.adaptiveAdditionalInfoSortBy,
  });

  final List<BaseItemDto> childrenForList;
  final BaseItemDto parent;
  final BaseItemDto? genreFilter;
  final bool albumShowsYearAndDurationInstead;
  final SortBy? adaptiveAdditionalInfoSortBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterArtistScreens = ref.watch(finampSettingsProvider.genreFilterArtistScreens);
    return SliverList(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        final BaseItemDto item = childrenForList[index];
        final itemType = BaseItemDtoType.fromItem(item);
        return ItemWrapper(
          key: ValueKey(item.id),
          item: item,
          genreFilter: (itemType == BaseItemDtoType.artist && filterArtistScreens) ? genreFilter : null,
          albumShowsYearAndDurationInstead: albumShowsYearAndDurationInstead,
          adaptiveAdditionalInfoSortBy: adaptiveAdditionalInfoSortBy,
        );
      }, childCount: childrenForList.length),
    );
  }
}
