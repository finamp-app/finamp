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

/// [hiddenIds] holds locally hidden items and items tagged on the server.
bool isItemHidden(BaseItemDto item, Set<BaseItemId> hiddenIds) {
  if (hiddenIds.contains(item.id) || (item.tags?.any(_isHiddenTag) ?? false)) {
    return true;
  }
  final albumId = item.albumId;
  return albumId != null && hiddenIds.contains(albumId);
}

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
