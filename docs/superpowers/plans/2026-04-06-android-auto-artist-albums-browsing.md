# Android Auto: Artist Albums Browsing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user taps an artist in Android Auto, show an "Instant Mix" option followed by the artist's albums, so the user can either start a mix immediately or pick a specific album.

**Architecture:** All changes are in a single file (`lib/services/android_auto_helper.dart`). Artists are removed from the "playable" set so they become browsable. `getMediaItems` prepends a synthetic "Instant Mix" item to the artist browse list. `playFromMediaId` handles that item by moving the `instantMix` check before the `_isPlayable` guard and adding artist-specific offline/online handling.

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

---

### Task 3: Prepend "Instant Mix" item to artist browse list and handle playback

**Files:**
- Modify: `lib/services/android_auto_helper.dart`

Two changes must land together. `getMediaItems` prepends the synthetic item; `playFromMediaId` handles it when tapped.

- [ ] **Step 1: Prepend a synthetic "Instant Mix" `MediaItem` in `getMediaItems`**

In `getMediaItems`, after the existing `shuffleAll` block (around line 622), add:

```dart
if (itemId.contentType == TabContentType.artists &&
    itemId.parentType == MediaItemParentType.collection) {
  final instantMixId = MediaItemId(
    contentType: TabContentType.artists,
    parentType: MediaItemParentType.instantMix,
    itemId: itemId.itemId,
  );
  mediaItems.add(MediaItem(
    id: instantMixId.toString(),
    title: AppLocalizations.of(GlobalSnackbar.materialAppScaffoldKey.currentContext!)?.instantMix ?? "Instant Mix",
    playable: true,
  ));
}
```

- [ ] **Step 2: Move `instantMix` check before `_isPlayable` guard in `playFromMediaId` and add artist handling**

Currently `playFromMediaId` has this order:
1. `_isPlayable` guard (returns early for artists — blocks instantMix items)
2. `instantMix` block

Move the `instantMix` block to run BEFORE the `_isPlayable` guard, and replace its existing logic with artist-aware handling. Find the current structure:

```dart
    // shouldn't happen, but just in case
    if (!_isPlayable(contentType: itemId.contentType)) {
      _androidAutoHelperLogger.warning(
        "Tried to play from media id with non-playable item type ${itemId.parentType.name}",
      );
      return;
    }

    if (itemId.parentType == MediaItemParentType.instantMix) {
      if (FinampSettingsHelper.finampSettings.isOffline) {
        List<DownloadStub> offlineItems;
        // If we're on the tracks tab, just get all of the downloaded items
        offlineItems = await _downloadsService.getAllTracks(
          // nameFilter: widget.searchTerm,
          viewFilter: finampUserHelper.currentUser?.currentView?.id,
          nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
        );

        var items = offlineItems.map((e) => e.baseItem).whereNotNull().toList();

        items = sortItems(
          items,
          FinampSettingsHelper.finampSettings.tabSortBy[TabContentType.tracks]!,
          FinampSettingsHelper.finampSettings.tabSortOrder[TabContentType.tracks]!,
        );

        final indexOfSelected = items.indexWhere((element) => element.id == itemId.itemId);

        return await queueService.startPlayback(
          items: items,
          startingIndex: indexOfSelected,
          source: QueueItemSource(
            name: const QueueItemSourceName(type: QueueItemSourceNameType.mix),
            type: QueueItemSourceType.allTracks,
            id: itemId.itemId!,
            item: items[indexOfSelected],
          ),
        );
      } else {
        return await audioServiceHelper.startInstantMixForItem(await _jellyfinApiHelper.getItemById(itemId.itemId!));
      }
    }
```

Replace with:

```dart
    if (itemId.parentType == MediaItemParentType.instantMix) {
      if (itemId.contentType == TabContentType.artists) {
        final parentItem = await getParentFromId(itemId.itemId!);
        if (FinampSettingsHelper.finampSettings.isOffline) {
          final artistAlbums = await getBaseItems(MediaItemId(
            contentType: TabContentType.artists,
            parentType: MediaItemParentType.collection,
            itemId: itemId.itemId,
          ));
          final List<BaseItemDto> allTracks = [];
          for (final album in artistAlbums) {
            allTracks.addAll(await _downloadsService.getCollectionTracks(album, playable: true));
          }
          return await queueService.startPlayback(
            items: allTracks,
            source: QueueItemSource(
              type: QueueItemSourceType.artist,
              name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: parentItem?.name),
              id: itemId.itemId!,
              item: parentItem,
            ),
            order: FinampPlaybackOrder.linear,
          );
        } else {
          return await audioServiceHelper.startInstantMixForArtists([parentItem!]);
        }
      }
      if (FinampSettingsHelper.finampSettings.isOffline) {
        List<DownloadStub> offlineItems;
        // If we're on the tracks tab, just get all of the downloaded items
        offlineItems = await _downloadsService.getAllTracks(
          // nameFilter: widget.searchTerm,
          viewFilter: finampUserHelper.currentUser?.currentView?.id,
          nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
        );

        var items = offlineItems.map((e) => e.baseItem).whereNotNull().toList();

        items = sortItems(
          items,
          FinampSettingsHelper.finampSettings.tabSortBy[TabContentType.tracks]!,
          FinampSettingsHelper.finampSettings.tabSortOrder[TabContentType.tracks]!,
        );

        final indexOfSelected = items.indexWhere((element) => element.id == itemId.itemId);

        return await queueService.startPlayback(
          items: items,
          startingIndex: indexOfSelected,
          source: QueueItemSource(
            name: const QueueItemSourceName(type: QueueItemSourceNameType.mix),
            type: QueueItemSourceType.allTracks,
            id: itemId.itemId!,
            item: items[indexOfSelected],
          ),
        );
      } else {
        return await audioServiceHelper.startInstantMixForItem(await _jellyfinApiHelper.getItemById(itemId.itemId!));
      }
    }

    // shouldn't happen, but just in case
    if (!_isPlayable(contentType: itemId.contentType)) {
      _androidAutoHelperLogger.warning(
        "Tried to play from media id with non-playable item type ${itemId.parentType.name}",
      );
      return;
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
git commit -m "feat(android-auto): add Instant Mix option to artist browse list"
```

---

## Manual Testing Checklist

Run on a device or emulator with Android Auto connected (or use the Desktop Head Unit app).

**Online mode:**
- [ ] Browse Artists → tap any artist → see "Instant Mix" as first item, followed by albums
- [ ] Tap "Instant Mix" → instant mix starts for that artist
- [ ] Tap an album from the list → album plays
- [ ] Genre browsing still works: tap a genre → album list → tap album → plays

**Offline mode (download a few albums first):**
- [ ] Browse Artists → tap an artist with downloaded albums → see "Instant Mix" + album list
- [ ] Tap "Instant Mix" → all downloaded tracks for that artist play
- [ ] Tap a downloaded album → album plays
- [ ] Tap an artist with no downloaded content → "Instant Mix" item only (or empty, no crash)

**Voice search regression:**
- [ ] Voice search for an artist in offline mode → plays artist tracks (not albums)

**Regression:**
- [ ] Albums tab: tap an album → plays (unchanged)
- [ ] Playlists tab: tap a playlist → plays (unchanged)
- [ ] Tracks tab: tap a track → plays (unchanged)
- [ ] Search: search for an artist → browsable, shows Instant Mix + albums on tap
