# Android Auto: Artist Albums Browsing

**Date:** 2026-04-06
**Branch:** redesign (feature built on top of)
**Status:** Approved

## Problem

When a user taps an artist in Android Auto, music starts playing immediately via an instant mix. There is no way to browse the artist's albums and choose which one to play. This is inconvenient when the user wants to listen to a specific album rather than a shuffle of all tracks.

## Goal

Tapping an artist in Android Auto drills down into a list of that artist's albums. The user then taps an album to play it. This mirrors how genres already work.

## Design

### Behaviour change

Artists change from **playable** to **browsable-only**, consistent with genres.

| Content type | Before | After  |
|--------------|--------|--------|
| Albums       | playable | playable (no change) |
| Playlists    | playable | playable (no change) |
| Tracks       | playable | playable (no change) |
| Genres       | browsable | browsable (no change) |
| Artists      | playable (instant mix) | browsable (shows albums) |

### Navigation flow

```
Artists root
  └── [Artist name]         ← tap → shows albums (was: instant mix)
        └── [Album name]    ← tap → plays album (unchanged)
```

### Files changed

#### `lib/services/android_auto_helper.dart`

**1. `_isPlayable` (line ~1172)**

Remove `TabContentType.artists` from the return expression so artists are no longer considered playable by Android Auto:

```dart
// Before
return tabContentType == TabContentType.albums ||
    tabContentType == TabContentType.playlists ||
    tabContentType == TabContentType.artists ||
    tabContentType == TabContentType.tracks;

// After
return tabContentType == TabContentType.albums ||
    tabContentType == TabContentType.playlists ||
    tabContentType == TabContentType.tracks;
```

**2. `getBaseItems` — offline artist path (lines ~162–175)**

The offline artist branch currently flattens all tracks from every album into a single list. Since artists are now browsable, it should return albums instead (same pattern as the offline genre path directly above it):

```dart
// Before
final List<BaseItemDto> allTracks = [];
for (var album in artistAlbums) {
  allTracks.addAll(await _downloadsService.getCollectionTracks(album, playable: true));
}
return allTracks;

// After
return artistAlbums;
```

**3. `playFromMediaId` — artist instant-mix block (lines ~694–712)**

This block starts an instant mix when an artist is played. It is now unreachable since artists are no longer playable. Remove it.

### What does not change

- Online browsing already returns albums for a tapped artist (`getBaseItems` sets `includeItemTypes = TabContentType.albums.itemType` for artists with `parentType == collection`). No change needed.
- Albums remain playable — tapping an album plays it as before.
- All other content types are unaffected.

## Out of scope

A settings toggle to revert to instant-mix behaviour was considered but deferred. The browsable-first experience is the correct default and the toggle can be added later if there is demand.

## Testing notes

- Online mode: browse Artists → tap artist → should see album list → tap album → playback starts
- Offline mode: same flow, using locally downloaded albums
- Verify no regression on albums, playlists, tracks, and genres
