# Apple Watch ↔ phone protocol

The watch app (`ios/FinampWatch Watch App/`, SwiftUI) holds no Jellyfin token and runs none of Finamp's code. Everything
it shows or does goes through the requests and pushes below. On the phone, `WatchBridge.swift` relays them over the
`com.unicornsonlsd.finamp-ios/watch` method channel to `WatchHandler` (`watch_helper.dart`), which answers with
Finamp's own providers and services.

**Changing a request or push:** update the watch (`PhoneConnection.swift`), the phone (`watch_helper.dart`) and this
file together. `test/watch_protocol_test.dart` fails when the three disagree on which requests and pushes exist.

## Requests (watch → phone)

Sent as `sendMessage(["method": m, "args": {…}])`; the reply is `{result}`, `{artworks, missing}` or `{error}`.

| Request | Args | Result |
|---|---|---|
| `list` | `type`, `parentId?`, `offset`, `limit` | rows, paged; a page can end early (≤ 40 KB), only an empty page means the end. `type`: `artists`, `albums`, `playlists`, `tracks`, `favorites`, `favoriteAlbums`, `favoriteArtists`, `downloads`; with `parentId`: a collection's tracks or an artist's albums |
| `home` | — | `{recent, newAlbums, actions, theme}` |
| `search` | `query` | `{artists, albums, playlists, tracks}`, 5 each |
| `play` | `type`, `parentId?`, `startId?`, `shuffle`; `artist` + `albumShuffle`; `tracks` + `index`, `startId`; `search` + `query` | `true` |
| `artistInfo` | `id` | `{tracks, albums, favorite, downloaded, downloadLock?}` |
| `downloadState` | `id` | `{downloaded, downloadLock?}` |
| `download` | `id`, `transcode?`, `locationId?`, `confirmed?` | `{status: downloading \| alreadyDownloaded}` or `{ask: transcode \| location \| confirm, …}` |
| `favorite` | `id`, `favorite` | the resulting state (bool), or an error while offline |
| `control` | `action`: `playPause`, `next`, `previous`, `toggleLoop`, `togglePlaybackOrder`, `toggleRadio`, or `skipTo` + `id` | `true` |
| `nowPlaying` | — | the now-playing dict (below) |
| `queue` | — | up to 30 upcoming rows |
| `shuffleAll` | — | `true` |
| `quickAction` | `index`, `action` | `true` (refused if Finamp's list changed) |
| `output` | — | `{route, routeType, volume}` |
| `setVolume` | `volume` 0…1 | `true` |
| `settings` | — | `{transcoding, offline}` |
| `setSetting` | `name` (`transcoding` \| `offline`), `enabled` | `true`, or `{reload, reloadButton, archive}` when Finamp asks to reload the queue |
| `reloadQueue` | `archive` | `true` |
| `showOutputPicker` | — | `"shown"` or `"pending"` (answered by `WatchBridge`, not Flutter) |
| `artworks` | `items: [{id, size}]` | `{artworks: {"<id>-<size>": JPEG}, missing}` (`WatchBridge` encodes the JPEGs) |

**Row:** `{id, name, subtitle, artistId, artworkKey, artworkUrl, blurHash, artistArtworkUrl, duration, year,
trackCount, favorite, downloaded, downloadLock?, kind, artists?}`.

**Now playing:** `{hasTrack, id, title, artist, artworkKey, artworkUrl, blurHash, albumId, album, albumArtist,
albumArtistId, artists, audio, duration, position, updatedAt, playing, advancing, loop, shuffled, radio, radioAvailable,
favorite, upNext, theme}`; `upNext`
holds the next two tracks' `{id, artworkKey, artworkUrl}` so the watch can load their covers ahead. The watch counts
`position` on from `updatedAt` only while `advancing` (playing and not loading or buffering), so its time stops with
the phone's when a track can't load; `playing` still sets the play/pause button. `loop` (`none` \| `one` \| `all`),
`shuffled`, `radio` and `radioAvailable` (radio is on and can run for this queue) drive the queue's buttons; the
`toggle…` actions cycle them as Finamp's queue does, and `toggleLoop` does nothing while radio is on.

## Pushes (phone → watch)

Sent live while the watch app is reachable; the application context always holds the latest of each.

| Push | Value |
|---|---|
| `nowPlaying` | the now-playing dict |
| `theme` | `light` or `dark`, from Finamp's theme setting |
| `accent` | Finamp's colour scheme as ARGB (its `getColorScheme`, AMOLED included), `{light, dark}` each with `primary`, `surface`, `onSurface`, `onSurfaceVariant`, `container` (primaryContainer), `onContainer` (onPrimaryContainer) |
| `account` | `user-id@server-id`, or empty when logged out |
| `transcoding` | Finamp's transcoding setting |
| `offline` | Finamp's Offline Mode |
| `volume` | Finamp's own volume, 0…1 |
| `airPlay` | whether playback goes to AirPlay |

## Flutter ↔ iOS (same channel)

Flutter → iOS: the pushes above, plus `watchState` (is a watch app installed). iOS → Flutter: every watch request, plus
`watchState {available}` when the watch app appears or goes away.
