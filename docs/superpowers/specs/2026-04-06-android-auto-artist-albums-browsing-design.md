# Android Auto: Artist Albums Browsing

**Date:** 2026-04-06
**Branch:** redesign (feature built on top of)
**Status:** Approved (revised)

## Problem

When a user taps an artist in Android Auto, music starts playing immediately via an instant mix. There is no way to browse the artist's albums and choose which one to play.

## Goal

Tapping an artist drills down into a list that shows **Instant Mix** as the first item, followed by all the artist's albums. The user can either start an instant mix immediately or pick a specific album to play.

## Design

### Behaviour change

Artists change from **directly playable** to **browsable**, but retain instant mix access via a synthetic first item in the browse list.

| Content type | Before | After  |
|--------------|--------|--------|
| Albums       | playable | playable (no change) |
| Playlists    | playable | playable (no change) |
| Tracks       | playable | playable (no change) |
| Genres       | browsable | browsable (no change) |
| Artists      | playable (instant mix on tap) | browsable → Instant Mix + albums |

### Navigation flow

```
Artists root
  └── [Artist name]            ← tap → shows browse list
        ├── Instant Mix        ← tap → starts instant mix
        ├── [Album 1]          ← tap → plays album
        ├── [Album 2]          ← tap → plays album
        └── ...
```

### Files changed

#### `lib/services/android_auto_helper.dart`

**1. `_isPlayable` (line ~1172)**

Remove `TabContentType.artists` so artists are browsable, not directly playable:

```dart
// artists and genres have subcategories, so they should be browsable but not playable
bool _isPlayable({BaseItemDto? item, TabContentType? contentType}) {
  final tabContentType = TabContentType.fromItemType(item?.type ?? contentType?.itemType.jellyfinName ?? "Audio");
  return tabContentType == TabContentType.albums ||
      tabContentType == TabContentType.playlists ||
      tabContentType == TabContentType.tracks;
}
```

**2. `getBaseItems` — offline artist path**

Return albums directly (not a flattened track list), so the browse path shows albums:

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

**3. `_searchPlayFromQuery` — offline artist voice search**

Since `getBaseItems` now returns albums for artists, the voice-search offline path must flatten them to tracks before calling `startPlayback`:

```dart
final artistAlbums = await getBaseItems(MediaItemId(...));
final List<BaseItemDto> allTracks = [];
for (final album in artistAlbums) {
  allTracks.addAll(await _downloadsService.getCollectionTracks(album, playable: true));
}
await queueService.startPlayback(items: allTracks, ...);
```

**4. `getMediaItems` — prepend Instant Mix item for artist browse**

When listing an artist's contents (`contentType == artists`, `parentType == collection`), prepend a synthetic "Instant Mix" `MediaItem` before the albums. Its ID is a `MediaItemId` with `parentType: instantMix` and the artist's `itemId`:

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
    title: AppLocalizations.of(context)!.instantMix,
    playable: true,
  ));
}
```

**5. `playFromMediaId` — move `instantMix` check before `_isPlayable` guard; add artist handling**

The `instantMix` block must run before the `_isPlayable` guard (since artists are no longer playable). Add artist-specific handling inside it:

- **Online:** `audioServiceHelper.startInstantMixForArtists([parentItem])`
- **Offline:** get artist albums via `getBaseItems`, flatten to tracks, call `startPlayback`

The previous dead-code artist instant-mix block (which fired when artists were directly playable) is removed entirely.

### What does not change

- Online `getBaseItems` for artists already returns albums (no change needed there).
- Albums remain playable — tapping an album plays it as before.
- All other content types are unaffected.

## Testing notes

- Online: browse Artists → tap artist → see "Instant Mix" + album list → tap Instant Mix → instant mix starts; tap album → album plays
- Offline: same flow using downloaded content; Instant Mix plays all downloaded tracks for that artist
- Voice search for artist in offline mode still plays artist tracks (regression test)
- No regression on albums, playlists, tracks, genres
