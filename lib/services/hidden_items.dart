import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';

/// Jellyfin tag that marks an item as hidden for every user on the server (#1179).
const hiddenTag = "hidden";

/// Keeps `excludeItemIds` query strings well under common proxy URL limits.
const maxExcludedIds = 150;

enum HideAction { askScope, showLocalNotice, hideLocal, hideOnServer }

enum UnhideBlocked { serverAdminOnly, offline, hiddenViaAlbum }

typedef UnhideAction = ({bool clearLocal, bool clearTag, UnhideBlocked? blocked});

bool _isHiddenTag(String tag) => tag.toLowerCase() == hiddenTag;

bool hasHiddenTag(BaseItemDto item) => item.tags?.any(_isHiddenTag) ?? false;

/// [hiddenIds] holds locally hidden items and items tagged on the server. The item's own tags aren't checked:
/// cached items keep the tags they were loaded with, so they'd stay hidden after an unhide until lists reload.
bool isItemHidden(BaseItemDto item, Set<BaseItemId> hiddenIds) {
  if (hiddenIds.contains(item.id)) {
    return true;
  }
  final albumId = item.albumId;
  return albumId != null && hiddenIds.contains(albumId);
}

/// Items to list, each with its index in [items] so taps and removals still refer to the full list.
List<(int, T)> visibleEntries<T>(List<T> items, bool Function(T) isHidden, HiddenItemsDisplay display) => [
  for (final (index, item) in items.indexed)
    if (display == HiddenItemsDisplay.greyOut || !isHidden(item)) (index, item),
];

/// Removes hidden items and returns the new index of the start item.
/// [keepStart] keeps a hidden start item that the user picked on purpose.
(List<T>, int) withoutHidden<T>(
  List<T> items,
  bool Function(T) isHidden, {
  int startIndex = 0,
  bool keepStart = false,
}) {
  final kept = <T>[];
  int? newStart;
  for (var i = 0; i < items.length; i++) {
    final keep = (keepStart && i == startIndex) || !isHidden(items[i]);
    if (!keep) continue;
    if (i >= startIndex) newStart ??= kept.length;
    kept.add(items[i]);
  }
  return (kept, newStart ?? 0);
}

/// Removes hidden tracks from a new queue. A single track is always a deliberate pick, so it's kept;
/// [keepStart] keeps a tapped hidden track. A null [startIndex] (shuffled order) filters every track.
(List<BaseItemDto>, int?) prepareQueueItems(
  List<BaseItemDto> items,
  int? startIndex,
  Set<BaseItemId> hiddenIds, {
  bool keepStart = false,
}) {
  if (items.length <= 1) return (items, startIndex);
  final (kept, newStart) = withoutHidden(
    items,
    (item) => isItemHidden(item, hiddenIds),
    startIndex: startIndex ?? 0,
    keepStart: keepStart && startIndex != null,
  );
  return (kept, startIndex == null ? null : newStart);
}

/// Changes only `Tags`: Jellyfin's update endpoint overwrites every field, so the rest must round-trip untouched.
Map<String, dynamic> withHiddenTag(Map<String, dynamic> itemJson, bool hidden) {
  final tags = [...(itemJson["Tags"] as List? ?? const []).cast<String>()];
  final hasTag = tags.any(_isHiddenTag);
  if (hidden && !hasTag) {
    tags.add(hiddenTag);
  } else if (!hidden) {
    tags.removeWhere(_isHiddenTag);
  }
  return {...itemJson, "Tags": tags};
}

HideAction resolveHideAction({
  required bool isAdmin,
  required bool isOffline,
  required HideScope scope,
  required bool localNoticeShown,
}) {
  if (!isAdmin) {
    return localNoticeShown ? HideAction.hideLocal : HideAction.showLocalNotice;
  }
  if (isOffline) {
    return HideAction.hideLocal;
  }
  return switch (scope) {
    HideScope.ask => HideAction.askScope,
    HideScope.thisDevice => HideAction.hideLocal,
    HideScope.everyone => HideAction.hideOnServer,
  };
}

UnhideAction resolveUnhideAction({
  required bool isAdmin,
  required bool isOffline,
  required bool inLocal,
  required bool hasTag,
}) {
  // Clearing only the local hide would leave a tagged item hidden, so don't offer it.
  if (hasTag && !isAdmin) {
    return (clearLocal: false, clearTag: false, blocked: UnhideBlocked.serverAdminOnly);
  }
  if (hasTag && isOffline) {
    return (clearLocal: false, clearTag: false, blocked: UnhideBlocked.offline);
  }
  if (!inLocal && !hasTag) {
    return (clearLocal: false, clearTag: false, blocked: UnhideBlocked.hiddenViaAlbum);
  }
  return (clearLocal: inLocal, clearTag: hasTag, blocked: null);
}

/// Server-side exclusion keeps random fetches full; past the cap, fetch extra and let the queue filter the rest.
({List<BaseItemId> exclude, int fetchLimit}) excludeIdsFor(Set<BaseItemId> hiddenIds, {required int limit}) {
  final exclude = hiddenIds.take(maxExcludedIds).toList();
  final notExcluded = hiddenIds.length - exclude.length;
  return (exclude: exclude, fetchLimit: limit + (notExcluded < limit ? notExcluded : limit));
}
