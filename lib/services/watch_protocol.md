# Apple Watch ↔ phone protocol

The watch app (`ios/FinampWatch Watch App/`, SwiftUI) holds no Jellyfin token, never connects to the internet itself
and runs none of Finamp's code. Everything it shows or does, covers included, goes through the requests and pushes
below. On the phone, `WatchBridge.swift` relays them over the `com.unicornsonlsd.finamp-ios/watch` method channel to `WatchHandler` (`watch_helper.dart`), which answers with
Finamp's own providers and services.

**Changing a request or push:** update the watch (`PhoneConnection.swift`), the phone (`watch_helper.dart`) and this
file together. `test/watch_protocol_test.dart` fails when the three disagree on which requests and pushes exist.

## Requests (watch → phone)

Sent as `sendMessage(["method": m, "args": {…}])`; the reply is `{result}`, `{artworks, missing}` or `{error, code?}`.
Each also carries `n`, the watch's count of requests handed to WatchConnectivity since its launch: only for the logs
(`WatchBridge` logs a gap as requests that never arrived); no answer depends on it.
While no one is logged in to Finamp on the phone, every request is refused with code `loggedOut` (the watch shows its
login screen from the `account` push).

| Request | Args | Result |
|---|---|---|
| `list` | `type`, `parentId?`, `offset`, `limit` | rows, paged; a page can end early (≤ 40 KB), only an empty page means the end. `type`: `artists`, `albums`, `playlists`, `tracks`, `favorites`, `favoriteAlbums`, `favoriteArtists`, `downloads`; with `parentId`: a collection's tracks, or an artist's albums as Finamp's artist screen lists them (`artists`: where they're the album artist; `appearsOn`: albums they perform on, without those) |
| `home` | — | `{recent, newAlbums, actions}` |
| `search` | `query` | `{artists, performingArtists, albums, playlists, tracks}`, 5 each; `artists` are album artists, `performingArtists` the artists credited only on tracks; `tracks` those whose name matches, then the found artists' tracks as Finamp plays an artist (`getArtistTracksProvider`); `play` with `search` plays the same list |
| `play` | `type`, `parentId?`, `startId?`, `shuffle`; `artist` + `albumShuffle`; `tracks` and `favorites` + `index`, `startId`; `search` + `query` | `true` |
| `artistInfo` | `id` | `{tracks, albums, favorite, downloaded, downloadLock?, sections}`; `albums` counts the album-artist albums, `sections` is the order of the artist page's album sections (`albums`, `appearsOn`) from Finamp's setting |
| `favoritesCount` | — | how many favourite tracks there are (int): Jellyfin's total, or the downloaded favourites offline |
| `item` | `id` | one row, as in `list` (e.g. the playing track's album, before Playback opens it) |
| `downloadState` | `id` | `{downloaded, downloadLock?}` |
| `deleteDownload` | `id` | `{status: deleted \| notDownloaded, message?}`; the watch asks first, as Finamp's delete button does |
| `download` | `id`, `transcode?`, `locationId?`, `confirmed?` | `{status: downloading \| alreadyDownloaded}` or `{ask: transcode \| location \| confirm, …}` |
| `playlistMenu` | `id` | Finamp's playlist menu for a track: `{favorite, color, playlists}`, `color` the track's cover colour Finamp themes the menu with (ARGB, made readable on black), `playlists` as rows sorted by name with `included` (true only for the playlist the track is playing from, which comes first; Finamp doesn't look the others up); an error while offline |
| `playlistToggle` | `id`, `playlistId`, `add` | whether the playlist now holds the track, added or removed with Finamp's own functions; an error while offline |
| `favorite` | `id`, `favorite` | Finamp's state right away (bool; the server's answer follows in `favoriteStates`), or an error while offline |
| `control` | `action`: `playPause`, `next`, `previous`, `toggleLoop`, `togglePlaybackOrder`, `toggleRadio`, or `skipTo` + `id`; also `pause` and `play`, which `WatchBridge` itself uses around a phone call taken on another device (the watch sends `playPause`) | `true` |
| `nowPlaying` | — | the now-playing dict (below) |
| `queue` | — | up to 30 upcoming rows |
| `shuffleAll` | — | `true` |
| `quickAction` | `index`, `action` | `true` (refused if Finamp's list changed) |
| `output` | — | `{route, routeType, volume}` |
| `setVolume` | `volume` 0…1 | `true` |
| `seek` | `position` (seconds), `queueEntryId` | `true`; `false`, not seeking, when that queue entry is no longer playing |
| `settings` | — | `{transcoding, offline}` |
| `setSetting` | `name` (`transcoding` \| `offline`), `enabled` | `true`, or `{reload, reloadButton, archive}` when Finamp asks to reload the queue |
| `reloadQueue` | `archive` | `true` |
| `showOutputPicker` | — | `"shown"` or `"pending"` (answered by `WatchBridge`, not Flutter) |
| `artworks` | `items: [{id, size}]` | `{artworks: {"<id>-<size>": JPEG}, missing}` (Flutter names the cover's file, `WatchBridge` scales it to a JPEG straight from the file; a key in neither is left for the watch to ask again) |

**Row:** `{id, name, subtitle, artistId, artworkKey, blurHash, duration, year,
releaseDate, trackCount, favorite, downloaded, downloadLock?, kind, artists?}`.

**Now playing:** `{hasTrack, id, queueEntryId, title, artist, artworkKey, blurHash, albumId, album, albumArtist,
albumArtistId, artists, features, duration, position, updatedAt, speed, playing, advancing, loop, shuffled, radio, radioAvailable,
favorite, upNext, queueEntryIds, coverColor, shortFeatures}`; `features` holds the player's feature chips as Finamp's player shows them
(the user's chip settings, in their order; `E` for explicit, empty with chips turned off); `upNext`
holds the next two tracks' `{id, artworkKey}` so the watch can load their covers ahead; `queueEntryIds` the queue
entries the `queue` request lists, so the queue sheet reloads when they change. The watch counts
`position` on from `updatedAt` only while `advancing` (playing and not loading or buffering), so its time stops with
the phone's when a track can't load; `playing` still sets the play/pause button. `loop` (`none` \| `one` \| `all`),
`shuffled`, `radio` and `radioAvailable` (radio is on and can run for this queue) drive the queue's buttons; the
`toggle…` actions cycle them as Finamp's queue does, and `toggleLoop` does nothing while radio is on. `coverColor` is
the colour Finamp's player and queue take from the track's cover (their theme's primary, ARGB, lifted to read on the
watch's dark background); the queue's buttons use it while active. `shortFeatures` is the watch's short chips as a list in the
order the user set Finamp's chips, each only while its chip is on: `{type: explicit}`, `{type: plays, text}` (Finamp's
play count text), `{type: mode, mode: local \| transcoding \| direct}`, `{type: format, codec?, kbps?}`.

## Pushes (phone → watch)

Sent live while the watch app is reachable; the application context always holds the latest of each. Live updates
go one at a time: a message holds every value that changed since the last one (all of them when the watch comes back
in reach), the watch confirms it with an empty reply, and only then the next is sent. One that fails is not repeated;
the application context carries its values.

| Push | Value |
|---|---|
| `nowPlaying` | the now-playing dict |
| `accent` | Finamp's colour scheme as ARGB (its `getColorScheme`, AMOLED included), `{light, dark}` each with `primary`, `onPrimary`, `surface`, `onSurface`, `onSurfaceVariant` |
| `account` | `user-id@server-id`, or empty when logged out |
| `transcoding` | Finamp's transcoding setting |
| `offline` | Finamp's Offline Mode |
| `preferFavorites` | Finamp's "prefer adding to favourites over playlists": the heart's tap likes and its long press opens the playlist menu, or (off, Finamp's default) the other way round |
| `volume` | Finamp's own volume, 0…1 |
| `airPlay` | whether playback goes to AirPlay |
| `outputRoute` | `{route, routeType}`, as in `output`, on every audio route change (the Output sheet follows it) |
| `favoriteStates` | `{id: favorite}` for the last 20 items the watch favourited or unfavourited, as Finamp holds them: a change the server refuses flips back, as on the phone; empty after an account change |

## Flutter ↔ iOS (same channel)

Flutter → iOS: the pushes above, plus `watchState` (is a watch app installed). iOS → Flutter: every watch request
except `showOutputPicker` (the bridge answers it), `watchState {available}` when the watch app appears or goes away,
and `watchLog {lines}` with the watch's log lines.
