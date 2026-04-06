# Android Auto: Artist Albums Browsing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user taps an artist in Android Auto, show the artist's albums instead of immediately starting an instant mix.

**Architecture:** All changes are in a single file (`lib/services/android_auto_helper.dart`). Artists are removed from the "playable" set so Android Auto treats them as browsable folders (like genres). The offline artist path is updated to return albums rather than a flat track list. The now-unreachable artist instant-mix block is deleted.

**Tech Stack:** Flutter/Dart, `audio_service` package, Jellyfin API, Riverpod

---

### Task 1: Make artists browsable in `_isPlayable` and fix offline `getBaseItems`

**Files:**
- Modify: `lib/services/android_auto_helper.dart`

These two changes must land together — `_isPlayable` controls whether Android Auto shows a play button or a drill-down arrow, and the offline `getBaseItems` path must return albums (not tracks) to match the new browsable behaviour.

- [ ] **Step 1: Remove `TabContentType.artists` from `_isPlayable`**

At the bottom of `android_auto_helper.dart`, locate `_isPlayable` (currently around line 1172). Change:

```dart
// albums, playlists, and tracks should play when clicked
// clicking artists starts an instant mix, so they are technically playable
// genres has subcategories, so it should be browsable but not playable
bool _isPlayable({BaseItemDto? item, TabContentType? contentType}) {
  final tabContentType = TabContentType.fromItemType(item?.type ?? contentType?.itemType.jellyfinName ?? "Audio");
  return tabContentType == TabContentType.albums ||
      tabContentType == TabContentType.playlists ||
      tabContentType == TabContentType.artists ||
      tabContentType == TabContentType.tracks;
}
```

To:

```dart
// albums, playlists, and tracks should play when clicked
// artists and genres have subcategories, so they should be browsable but not playable
bool _isPlayable({BaseItemDto? item, TabContentType? contentType}) {
  final tabContentType = TabContentType.fromItemType(item?.type ?? contentType?.itemType.jellyfinName ?? "Audio");
  return tabContentType == TabContentType.albums ||
      tabContentType == TabContentType.playlists ||
      tabContentType == TabContentType.tracks;
}
```

- [ ] **Step 2: Fix the offline artist path in `getBaseItems` to return albums**

Locate the offline artist block inside `getBaseItems` (currently around lines 162–175):

```dart
} else if (itemId.contentType == TabContentType.artists) {
  final artistBaseItem = await getParentFromId(itemId.itemId!);

  final List<BaseItemDto> artistAlbums = (await _downloadsService.getAllCollections(
    baseTypeFilter: BaseItemDtoType.album,
    relatedTo: artistBaseItem,
  )).toList().map((e) => e.baseItem).whereNotNull().toList();
  artistAlbums.sort((a, b) => (a.premiereDate ?? "").compareTo(b.premiereDate ?? ""));

  final List<BaseItemDto> allTracks = [];
  for (var album in artistAlbums) {
    allTracks.addAll(await _downloadsService.getCollectionTracks(album, playable: true));
  }
  return allTracks;
}
```

Replace with:

```dart
} else if (itemId.contentType == TabContentType.artists) {
  final artistBaseItem = await getParentFromId(itemId.itemId!);

  final List<BaseItemDto> artistAlbums = (await _downloadsService.getAllCollections(
    baseTypeFilter: BaseItemDtoType.album,
    relatedTo: artistBaseItem,
  )).toList().map((e) => e.baseItem).whereNotNull().toList();
  artistAlbums.sort((a, b) => (a.premiereDate ?? "").compareTo(b.premiereDate ?? ""));

  return artistAlbums;
}
```

- [ ] **Step 3: Verify the app compiles**

```bash
flutter analyze lib/services/android_auto_helper.dart
```

Expected: no errors or new warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/services/android_auto_helper.dart
git commit -m "feat(android-auto): make artists browsable, show albums on tap"
```

---

### Task 2: Remove dead instant-mix code from `playFromMediaId`

**Files:**
- Modify: `lib/services/android_auto_helper.dart`

The artist instant-mix block in `playFromMediaId` is now unreachable — `_isPlayable` no longer returns true for artists, so `playFromMediaId` will never be called with `contentType == TabContentType.artists`. Delete it.

- [ ] **Step 1: Delete the artist instant-mix block**

Locate the block in `playFromMediaId` (currently around lines 694–712):

```dart
// get all tracks of current parent
final parentItem = await getParentFromId(itemId.itemId!);

// start instant mix for artists
if (itemId.contentType == TabContentType.artists) {
  if (FinampSettingsHelper.finampSettings.isOffline || parentItem == null) {
    final parentBaseItems = await getBaseItems(itemId);

    return await queueService.startPlayback(
      items: parentBaseItems,
      source: QueueItemSource(
        type: QueueItemSourceType.artist,
        name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: parentItem?.name),
        id: parentItem?.id ?? itemId.parentId!,
        item: parentItem,
      ),
      order: FinampPlaybackOrder.linear,
    );
  } else {
    return await audioServiceHelper.startInstantMixForArtists([parentItem]);
  }
}
```

Remove the `// start instant mix for artists` block entirely, leaving:

```dart
// get all tracks of current parent
final parentItem = await getParentFromId(itemId.itemId!);

final parentBaseItems = await getBaseItems(itemId);

await queueService.startPlayback(
  items: parentBaseItems,
  source: QueueItemSource(
    type: itemId.contentType == TabContentType.playlists ? QueueItemSourceType.playlist : QueueItemSourceType.album,
    name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: parentItem?.name),
    id: parentItem?.id ?? itemId.parentId!,
    item: parentItem,
  ),
);
```

- [ ] **Step 2: Verify the app compiles**

```bash
flutter analyze lib/services/android_auto_helper.dart
```

Expected: no errors or new warnings.

- [ ] **Step 3: Commit**

```bash
git add lib/services/android_auto_helper.dart
git commit -m "chore(android-auto): remove dead artist instant-mix code from playFromMediaId"
```

---

## Manual Testing Checklist

Run on a device or emulator with Android Auto connected (or use the Desktop Head Unit app).

**Online mode:**
- [ ] Browse Artists → tap any artist → album list appears (not instant playback)
- [ ] Tap an album from the artist → playback starts for that album
- [ ] Verify genre browsing still works: tap a genre → album list appears → tap album → plays

**Offline mode (download a few albums first):**
- [ ] Browse Artists → tap an artist with downloaded albums → album list appears
- [ ] Tap a downloaded album → playback starts
- [ ] Tap an artist with no downloaded content → empty list or graceful fallback (no crash)

**Regression:**
- [ ] Albums tab: tap an album → plays (unchanged)
- [ ] Playlists tab: tap a playlist → plays (unchanged)
- [ ] Tracks tab: tap a track → plays (unchanged)
- [ ] Search: search for an artist → result is browsable (shows albums on tap)
