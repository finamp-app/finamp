# Android Auto Browsing — Implementation Notes

## Overview

Finamp's Android Auto browse tree is implemented across two main files:

- `lib/services/music_player_background_task.dart` — builds the root menu (`_getRootMenu`)
- `lib/services/android_auto_helper.dart` — handles all `getChildren` / `onLoadChildren` requests

Browse tree IDs are JSON-serialised `MediaItemId` objects (defined in `lib/models/finamp_models.dart`).

---

## MediaItemId

```dart
class MediaItemId {
  TabContentType contentType;      // albums, artists, tracks, playlists, genres
  MediaItemParentType parentType;  // rootCollection, collection, instantMix, …
  String? itemId;                  // Jellyfin item ID (for a specific album/artist)
  String? parentId;
  String? nameFilter;              // letter browsing: '' = index, 'A'–'Z'/'#' = filtered page
  int? pageStartIndex;             // pagination offset (null = 0)
}
```

`nameFilter` and `pageStartIndex` were added specifically to encode browse state inside Android Auto node IDs, since Android Auto does not carry any other state between `getChildren` calls.

---

## Pagination

### Why it's needed

Android Auto communicates browse results over Binder IPC, which has a hard buffer limit of ~1 MB. Returning large collections (500+ albums) in a single `getChildren` response causes a **FAILED BINDER TRANSACTION** crash.

### Solution

Each root-collection page returns at most `_pageSize = 200` items. If more items exist, a non-playable **"More… (N remaining)"** node is appended whose ID encodes the next `pageStartIndex`. Selecting it triggers another `getChildren` call for the next page.

---

## Browse-by-Letter Hybrid

### Structure

```
Albums (root — flat list, page 1)
├── Browse by Letter          ← extra node, page 1 only
├── Abbey Road
├── Dark Side of the Moon
├── … (up to 200 albums)
└── More… (N remaining)

Browse by Letter
├── A
├── B
├── …
└── #

A (letter page)
├── Abbey Road
├── Achtung Baby
├── …
└── More… (N remaining)    ← only if > 200 results for this letter
```

### nameFilter encoding

| `nameFilter` value | Meaning |
|---|---|
| `null` | Flat paginated list (default) |
| `''` (empty string) | Letter index — return A–Z + # nodes |
| `'A'`–`'Z'` | Server-filtered page via Jellyfin `NameStartsWith` |
| `'#'` | Client-filtered page for non-alphabetic names |

### Code entry points

| Condition | Method called |
|---|---|
| `nameFilter == ''` | `_getLetterNodes()` |
| `nameFilter != null` | `_fetchLetterPage()` |
| `nameFilter == null` | `_fetchRootPage()` |

Letter browsing is only offered for **Albums** and **Artists** (not Tracks, Playlists, or Genres).

---

## Jellyfin API Changes

`NameStartsWith` was added as an optional query parameter to:

- `getItems()` in `jellyfin_api.dart` / `jellyfin_api.chopper.dart`
- `getAlbumArtists()` / `getArtists()` in the same files
- `getItemsWithTotalRecordCount()` / `_fetchGetItemsResponse()` in `jellyfin_api_helper.dart`

The `#` bucket cannot use `NameStartsWith` (Jellyfin doesn't support it). Instead, up to 500 items are fetched without a name filter and client-side filtered to items whose first character is not A–Z.

---

## Android Auto Learnings

### Content style hints

Set on the `MediaItem.extras` map:

| Key | Controls |
|---|---|
| `android.media.browse.CONTENT_STYLE_BROWSABLE_HINT` | How **browsable children** display (1=list, 2=grid, 3=category list, 4=category grid) |
| `android.media.browse.CONTENT_STYLE_PLAYABLE_HINT` | How **playable children** display |
| `android.media.browse.CONTENT_STYLE_SINGLE_ITEM_HINT` | How the **item itself** displays in its parent list |

Setting `BROWSABLE_HINT = 2` (grid) on a parent node causes children to render as grid tiles — which shows warning triangles if artwork is missing.

### A↔Z button

The A↔Z button in Android Auto is **entirely client-side**. It scrolls within the already-loaded item list and highlights letters that are present. There is no server callback or intercept point. It cannot be used to trigger a server-side letter filter.

### Alphabetical section headers

Android Auto **automatically injects** section headers for alphabetically sorted lists. These cannot be suppressed via any public API. On the Desktop Head Unit (DHU) emulator they may render duplicated compared to real hardware.

### DHU vs real hardware

The DHU emulator sometimes renders browse items differently from real Android Auto hardware — particularly around section headers and content style hints. Always verify UX on real hardware before drawing final conclusions.

### Binder IPC limit

~1 MB hard limit on the size of a single Binder IPC transaction. With rich `MediaItem` objects (artwork URIs, extras maps) this is exceeded well before 500 items. 200 items per page is a safe ceiling.

### playable: false

Non-playable browse nodes (folders, pagination nodes) must set `playable: false`. Selecting them triggers `getChildren`, not playback.
