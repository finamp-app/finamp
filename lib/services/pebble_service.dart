import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:get_it/get_it.dart';
import 'dart:async';

const int _PAGESIZE = 25;

enum PebbleBrowseType { albums, playlists, artists, genres }

class PebbleService {
  static const MethodChannel _channel = MethodChannel('finamp/pebble');

  static List<String> _lastItemIds = [];
  static List<String> _lastItemNames = [];
  static List<String> _lastSongIds = [];

  static PebbleBrowseType? _currentBrowseType;
  static String? _currentParentId;

  static Timer? _periodicUpdateTimer;
  static String? _currentMediaId;

  static Future<void> init() async {
    _channel.setMethodCallHandler(_handleMethodCallFromPhone);

    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    audioHandler.playbackState.listen((_) => _sendCurrentNowPlaying());
    audioHandler.mediaItem.listen((_) => _sendCurrentNowPlaying());
  }

  static Future<dynamic> _handleMethodCallFromPhone(MethodCall call) async {
    if (call.method != 'onPebbleCommand') return null;

    final args = call.arguments as Map<dynamic, dynamic>;
    final cmd = args['command'] as int;
    final receivedIndex = args['index'] as int?;

    final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

    switch (cmd) {
      case 1:
        await _sendBrowseListToPebble(PebbleBrowseType.albums, receivedIndex ?? 0);
        break;
      case 7:
        await _sendBrowseListToPebble(PebbleBrowseType.playlists, receivedIndex ?? 0);
        break;
      case 8:
        await _sendBrowseListToPebble(PebbleBrowseType.artists, receivedIndex ?? 0);
        break;
      case 9:
        await _sendBrowseListToPebble(PebbleBrowseType.genres, receivedIndex ?? 0);
        break;

      case 10: // CMD_OPEN_SONGS
        final browseIndex = receivedIndex ?? 0;
        if (browseIndex < 0 || browseIndex >= _lastItemIds.length) return;
        _currentParentId = _lastItemIds[browseIndex];
        await _sendSongsListToPebble(0);
        break;

      case 11: // CMD_LOAD_MORE_SONGS
        final offset = receivedIndex ?? 0;
        await _sendSongsListToPebble(offset);
        break;

      case 12: // CMD_PLAY_ALL
        if (_currentParentId != null) await _playParentItem();
        await _sendCurrentNowPlaying();
        break;

      case 13: // CMD_PLAY_SONG
        if (receivedIndex != null && receivedIndex < _lastSongIds.length) {
          await _playSingleSong(receivedIndex);
        }
        await _sendCurrentNowPlaying();
        break;

      case 3:
        try {
          final isPlaying = audioHandler.playbackState.value.playing;
          isPlaying ? await audioHandler.pause() : await audioHandler.play();
        } catch (e) {
          print('Pebble pause error: $e');
        }
        break;
      case 4:
        await audioHandler.skipToNext().catchError((e) => print('Pebble next error: $e'));
        break;
      case 5:
        await audioHandler.skipToPrevious().catchError((e) => print('Pebble prev error: $e'));
        break;
      case 6:
        await _sendCurrentNowPlaying();
        break;
      case 99:
        await _channel.invokeMethod('sendDataToPebble', {'data': 'Hello back from Finamp!'});
        break;
    }
    return null;
  }

  static Future<void> _sendBrowseListToPebble(PebbleBrowseType type, [int offset = 0]) async {
    _currentBrowseType = type;
    _currentParentId = null;

    try {
      final api = GetIt.instance<JellyfinApiHelper>();

      String? includeItemTypes;
      ArtistType? artistType;
      switch (type) {
        case PebbleBrowseType.albums:
          includeItemTypes = "MusicAlbum";
          break;
        case PebbleBrowseType.playlists:
          includeItemTypes = "Playlist";
          break;
        case PebbleBrowseType.artists:
          includeItemTypes = "MusicArtist";
          artistType = ArtistType.albumArtist;
          break;
        case PebbleBrowseType.genres:
          includeItemTypes = "MusicGenre";
          break;
      }

      final peekLimit = _PAGESIZE + 1;
      final result =
          await api.getItems(
            includeItemTypes: includeItemTypes,
            limit: peekLimit,
            startIndex: offset,
            artistType: artistType,
          ) ??
          [];

      final hasMore = result.length > _PAGESIZE;
      final itemsToSend = hasMore ? result.take(_PAGESIZE).toList() : result;

      final entries = itemsToSend
          .map((item) {
            String name = (item.name ?? 'Unknown').replaceAll('|', ' — ').replaceAll('~~', ' - ');
            if (name.length > 40) name = "${name.substring(0, 37)}...";
            return "$name|${item.id.toString()}";
          })
          .join("~~");

      final payload = "ALBUMLIST|${hasMore ? 1 : 0}~~$entries";
      await _channel.invokeMethod('sendDataToPebble', {'data': payload});

      if (offset == 0) {
        _lastItemIds = itemsToSend.map((a) => a.id.toString()).toList();
        _lastItemNames = itemsToSend.map((a) => a.name ?? 'Unknown').toList();
      } else {
        _lastItemIds.addAll(itemsToSend.map((a) => a.id.toString()));
        _lastItemNames.addAll(itemsToSend.map((a) => a.name ?? 'Unknown'));
      }
    } catch (e) {
      await _channel.invokeMethod('sendDataToPebble', {'data': 'Error: $e'});
    }
  }

  static Future<void> _sendSongsListToPebble([int offset = 0]) async {
    if (_currentParentId == null || _currentBrowseType == null) return;

    try {
      final jellyfinApiHelper = GetIt.I<JellyfinApiHelper>();
      final parentItem = await jellyfinApiHelper.getItemById(BaseItemId(_currentParentId!));
      if (parentItem == null) return;

      final peekLimit = _PAGESIZE + 1;

      List<BaseItemDto> result;
      switch (_currentBrowseType!) {
        case PebbleBrowseType.albums:
        case PebbleBrowseType.playlists:
          result =
              await jellyfinApiHelper.getItems(
                parentItem: parentItem,
                includeItemTypes: 'Audio',
                sortBy: 'ParentIndexNumber,IndexNumber,SortName',
                sortOrder: 'Ascending',
                startIndex: offset,
                limit: peekLimit,
              ) ??
              [];
          break;
        case PebbleBrowseType.artists:
          result =
              await jellyfinApiHelper.getItems(
                parentItem: parentItem,
                includeItemTypes: 'Audio',
                recursive: true,
                startIndex: offset,
                limit: peekLimit,
              ) ??
              [];
          break;
        case PebbleBrowseType.genres:
          result =
              await jellyfinApiHelper.getItems(
                genreFilter: parentItem,
                includeItemTypes: 'Audio',
                recursive: true,
                startIndex: offset,
                limit: peekLimit,
              ) ??
              [];
          break;
      }

      final hasMore = result.length > _PAGESIZE;
      final itemsToSend = hasMore ? result.take(_PAGESIZE).toList() : result;

      final entries = itemsToSend
          .map((item) {
            String name = (item.name ?? 'Unknown').replaceAll('|', ' — ').replaceAll('~~', ' - ');
            if (name.length > 40) name = "${name.substring(0, 37)}...";
            return "$name|${item.id.toString()}";
          })
          .join("~~");

      final parentName = (parentItem.name ?? 'Unknown').replaceAll('|', ' — ').replaceAll('~~', ' - ');
      final payload = "SONGLIST|$parentName|${hasMore ? 1 : 0}~~$entries";

      await _channel.invokeMethod('sendDataToPebble', {'data': payload});

      if (offset == 0) {
        _lastSongIds = itemsToSend.map((a) => a.id.toString()).toList();
      } else {
        _lastSongIds.addAll(itemsToSend.map((a) => a.id.toString()));
      }
    } catch (e) {
      await _channel.invokeMethod('sendDataToPebble', {'data': 'Error: $e'});
    }
  }

  static Future<void> _playParentItem() async {
    if (_currentParentId == null || _currentBrowseType == null) return;

    try {
      final jellyfinApiHelper = GetIt.I<JellyfinApiHelper>();
      final queueService = GetIt.instance<QueueService>();

      final parent = await jellyfinApiHelper.getItemById(BaseItemId(_currentParentId!));
      if (parent == null) return;

      List<BaseItemDto> tracks;
      QueueItemSource source;

      switch (_currentBrowseType!) {
        case PebbleBrowseType.albums:
          tracks =
              await jellyfinApiHelper.getItems(
                parentItem: parent,
                includeItemTypes: 'Audio',
                sortBy: 'ParentIndexNumber,IndexNumber,SortName',
                sortOrder: 'Ascending',
              ) ??
              [];
          source = QueueItemSource.rawId(
            type: QueueItemSourceType.album,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.shuffleAll),
            id: parent.id.raw,
            item: parent,
          );
          break;
        case PebbleBrowseType.playlists:
          tracks = await jellyfinApiHelper.getItems(parentItem: parent, includeItemTypes: 'Audio') ?? [];
          source = QueueItemSource.rawId(
            type: QueueItemSourceType.playlist,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.preTranslated),
            id: parent.id.raw,
            item: parent,
          );
          break;
        case PebbleBrowseType.artists:
          tracks =
              await jellyfinApiHelper.getItems(parentItem: parent, includeItemTypes: 'Audio', recursive: true) ?? [];
          source = QueueItemSource.rawId(
            type: QueueItemSourceType.artist,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.preTranslated),
            id: parent.id.raw,
            item: parent,
          );
          break;
        case PebbleBrowseType.genres:
          tracks =
              await jellyfinApiHelper.getItems(genreFilter: parent, includeItemTypes: 'Audio', recursive: true) ?? [];
          source = QueueItemSource.rawId(
            type: QueueItemSourceType.genre,
            name: const QueueItemSourceName(type: QueueItemSourceNameType.preTranslated),
            id: parent.id.raw,
            item: parent,
          );
          break;
      }

      if (tracks.isEmpty) return;

      await queueService.startPlayback(
        items: tracks,
        source: source,
        order: FinampPlaybackOrder.linear,
        startingIndex: 0,
      );
    } catch (e) {
      print('Pebble play-all error: $e');
      await _channel.invokeMethod('sendDataToPebble', {'data': 'Playback failed'});
    }
  }

  // FIXED: added small delay so the queue update is guaranteed before we skip
  static Future<void> _playSingleSong(int index) async {
    if (index < 0 || index >= _lastSongIds.length) return;

    final songId = _lastSongIds[index];
    try {
      final jellyfinApiHelper = GetIt.I<JellyfinApiHelper>();
      final queueService = GetIt.instance<QueueService>();
      final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();

      final track = await jellyfinApiHelper.getItemById(BaseItemId(songId));
      if (track == null) return;

      await queueService.addNext(items: [track]);

      // Give the background task a moment to update the queue before skipping
      await Future.delayed(const Duration(milliseconds: 150));

      final state = audioHandler.playbackState.value;

      if (state.playing) {
        await audioHandler.skipToNext();
      } else {
        await audioHandler.play();
      }
    } catch (e) {
      print('Pebble play-song error: $e');
      await _channel.invokeMethod('sendDataToPebble', {'data': 'Playback failed'});
    }
  }

  static Future<void> _sendCurrentNowPlaying() async {
    try {
      final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
      final media = audioHandler.mediaItem.value;
      final state = audioHandler.playbackState.value;

      if (media == null) {
        await _channel.invokeMethod('sendDataToPebble', {'data': 'NOWPLAYING|No track|Unknown|0|0|0'});
        return;
      }

      final newMediaId = media.id;
      if (_currentMediaId != newMediaId) _currentMediaId = newMediaId;

      int positionSeconds = state.position.inSeconds.clamp(0, 999999);

      final title = (media.title ?? 'Unknown').replaceAll('|', '');
      final artist = (media.artist ?? 'Unknown Artist').replaceAll('|', '');
      final duration = (media.duration?.inSeconds ?? 0).clamp(0, 999999);
      final isPlaying = state.playing ? 1 : 0;

      final payload = 'NOWPLAYING|$title|$artist|$positionSeconds|$duration|$isPlaying';
      await _channel.invokeMethod('sendDataToPebble', {'data': payload});
    } catch (e) {
      print('Pebble now-playing update error: $e');
    }
  }
}
