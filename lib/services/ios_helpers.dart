import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'android_auto_helper.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'finamp_user_helper.dart';
import 'jellyfin_api_helper.dart';
import 'queue_service.dart';

/// iOS-specific helpers for playback state sync and Siri media intents.

final _logger = Logger('IosHelpers');

/// Syncs playback state to iOS's MPNowPlayingInfoCenter.
///
/// TODO: This is a workaround because audio_service doesn't set
/// MPNowPlayingInfoCenter.playbackState on iOS (only on macOS).
/// This causes CarPlay's Now Playing screen to not reflect the correct
/// play/pause state when playback is started from the phone.
/// Consider contributing a fix upstream to audio_service.
class IosPlaybackStateSync {
  static const _channel = MethodChannel('com.unicornsonlsd.finamp/playback_state');

  /// Sets the playback state on iOS's MPNowPlayingInfoCenter.
  /// This is needed for CarPlay to show the correct play/pause state.
  static Future<void> setPlaybackState({required bool isPlaying}) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('setPlaybackState', {'isPlaying': isPlaying});
      _logger.fine('Set iOS playback state to ${isPlaying ? "playing" : "paused"}');
    } catch (e) {
      _logger.warning('Failed to set iOS playback state: $e');
    }
  }
}

/// Handles Siri media intent commands from iOS.
///
/// This enables voice commands like "Hey Siri, play [song/artist] on Finamp"
/// from anywhere on iOS (phone, CarPlay, AirPods, etc.).
class IosSiriHandler {
  static const _siriIntentChannel = MethodChannel('com.unicornsonlsd.finamp/siri_intent');

  /// Sets up the method channel handler for Siri media intents.
  /// Should be called once during app initialization.
  static void setup() {
    if (!Platform.isIOS) return;

    _siriIntentChannel.setMethodCallHandler((call) async {
      _logger.info("Received Siri intent: ${call.method}");

      switch (call.method) {
        case 'playFromSearch':
          await _handlePlayFromSearch(call.arguments as Map<dynamic, dynamic>?);
          break;
        case 'searchMedia':
          await _handleSearchMedia(call.arguments as Map<dynamic, dynamic>?);
          break;
        default:
          _logger.warning("Unknown Siri intent method: ${call.method}");
      }
    });

    _logger.info("Siri intent handler set up");
  }

  /// Handles Siri "Play X on Finamp" voice commands
  static Future<void> _handlePlayFromSearch(Map<dynamic, dynamic>? arguments) async {
    if (arguments == null) {
      _logger.warning("Siri playFromSearch called with null arguments");
      return;
    }

    final query = arguments['query'] as String?;
    final artist = arguments['artist'] as String?;
    final album = arguments['album'] as String?;
    final genre = arguments['genre'] as String?;
    final shuffle = arguments['shuffle'] as bool? ?? false;

    _logger.info("Siri playFromSearch - query: $query, artist: $artist, album: $album, genre: $genre, shuffle: $shuffle");

    // Build extras map similar to Android Auto
    final Map<String, dynamic> extras = {};
    if (artist != null) extras['android.intent.extra.artist'] = artist;
    if (album != null) extras['android.intent.extra.album'] = album;
    if (query != null) extras['android.intent.extra.title'] = query;

    // Use the existing Android Auto search logic
    final androidAutoHelper = GetIt.instance<AndroidAutoHelper>();
    final searchQuery = AndroidAutoSearchQuery(
      query ?? artist ?? album ?? genre ?? '',
      extras.isNotEmpty ? extras : null,
    );

    if (shuffle) {
      // If shuffle requested with no specific query, shuffle all (fast: 30 tracks)
      if (query == null && artist == null && album == null) {
        await _shuffleAll();
        return;
      }
    }

    await androidAutoHelper.playFromSearch(searchQuery);
  }

  static const _siriShuffleLimit = 30;

  /// Fast shuffle (same approach as CarPlay) — fetches 30 random tracks instead of 250.
  static Future<void> _shuffleAll() async {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final queueService = GetIt.instance<QueueService>();

    List<BaseItemDto>? items;

    if (FinampSettingsHelper.finampSettings.isOffline) {
      final downloadsService = GetIt.instance<DownloadsService>();
      items = (await downloadsService.getAllTracks(
        viewFilter: finampUserHelper.currentUser?.currentView?.id,
        nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
      )).map((e) => e.baseItem!).toList();
      items.shuffle();
      if (items.length > _siriShuffleLimit) {
        items = items.sublist(0, _siriShuffleLimit);
      }
    } else {
      items = await jellyfinApiHelper.getItems(
        parentItem: finampUserHelper.currentUser?.currentView,
        includeItemTypes: "Audio",
        sortBy: "Random",
        limit: _siriShuffleLimit,
      );
    }

    if (items != null && items.isNotEmpty) {
      await queueService.startPlayback(
        items: items,
        source: QueueItemSource.rawId(
          type: QueueItemSourceType.allTracks,
          name: const QueueItemSourceName(
            type: QueueItemSourceNameType.shuffleAll,
          ),
          id: "shuffleAll",
        ),
        order: FinampPlaybackOrder.shuffled,
      );
    }
  }

  /// Handles Siri "Search for X on Finamp" voice commands
  static Future<void> _handleSearchMedia(Map<dynamic, dynamic>? arguments) async {
    if (arguments == null) {
      _logger.warning("Siri searchMedia called with null arguments");
      return;
    }

    final query = arguments['query'] as String?;
    _logger.info("Siri searchMedia - query: $query");

    // For now, just play the search result (same as playFromSearch)
    // In the future, this could navigate to a search results screen
    await _handlePlayFromSearch(arguments);
  }
}
