import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/artist_content_provider.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/item_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

import '../models/music_slices.dart';

final _radioLogger = Logger("Radio");
final _radioRandom = Random();

/// Returns the amount of tracks that are needed to fill up the radio queue
int calculateRadioTracksNeeded() {
  // fetch enough (10 or more) tracks of at least ~2 minutes to fill the entire precache buffer
  final minUpcomingRadioTracks = max(10, FinampSettingsHelper.finampSettings.bufferDuration.inMinutes ~/ 2);
  final queueService = GetIt.instance<QueueService>();
  final currentQueue = queueService.getQueue();
  if (FinampSettingsHelper.finampSettings.radioEnabled) {
    if (![SavedQueueState.saving, SavedQueueState.pendingSave].contains(currentQueue.saveState)) {
      return 0;
    }
    final queueSize = currentQueue.nextUp.length + currentQueue.queue.length;
    return max(0, minUpcomingRadioTracks - queueSize);
  }
  return 0;
}

final List<DateTime> _radioCallTimestamps = [];
const int _radioCallLimit = 4;
const Duration _radioCallWindow = Duration(seconds: 20);

final _radioCacheStateStream = BehaviorSubject<RadioCacheState?>.seeded(null);
final _radioCacheStateStreamProvider = StreamProvider<RadioCacheState?>((ref) {
  if (_radioCacheStateStream.valueOrNull == null) {
    invalidateRadioCache();
  }
  GetIt.instance<MusicPlayerBackgroundTask>().refreshPlaybackStateAndMediaNotification();
  return _radioCacheStateStream;
});
final radioStateProvider = Provider<RadioCacheState?>((ref) {
  return ref.watch(_radioCacheStateStreamProvider).value;
});

Future<void> maybeAddRadioTracks() async {
  final queueService = GetIt.instance<QueueService>();
  final currentQueue = queueService.getQueue();

  if (_radioCacheStateStream.valueOrNull == null || !_radioCacheStateStream.value!.isStillValid()) {
    invalidateRadioCache();
  }

  final radioTracksNeeded = calculateRadioTracksNeeded();
  if (radioTracksNeeded > 0 && !_radioCacheStateStream.value!.generating && !_radioCacheStateStream.value!.queueing) {
    // Rate-limit: prevent running if called >= _radioCallLimit times within _radioCallWindow.
    final now = DateTime.now();
    _radioCallTimestamps.removeWhere((t) => now.difference(t) > _radioCallWindow);
    if (_radioCallTimestamps.length >= _radioCallLimit) {
      _radioLogger.warning(
        "maybeAddRadioTracks suppressed: called ${_radioCallTimestamps.length} times within the last ${_radioCallWindow.inSeconds}s.",
      );
      return;
    }
    _radioCallTimestamps.add(now);

    _radioLogger.fine("$radioTracksNeeded new radio tracks are needed");

    var localResult = _radioCacheStateStream.value!.copyWith(generating: true);
    _radioCacheStateStream.add(localResult);
    if (localResult.tracks.length < radioTracksNeeded) {
      _radioLogger.finer("Radio cache exhausted, generating new radio tracks");
      try {
        // generate new tracks, passing the existing cache to avoid generating duplicates in some modes
        // we still want to add the new tracks tot he existing cache instead of replacing, so that modes like reshuffle don't break
        final generatedTracks = await generateRadioTracks(
          radioTracksNeeded - localResult.tracks.length,
          cachedTracks: localResult.tracks,
        );
        localResult.tracks.addAll(generatedTracks);
        _radioLogger.finer("Successfully generated ${generatedTracks.length} new radio tracks.");
      } catch (e) {
        _radioLogger.warning("Couldn't generate radio tracks: $e");
      }
    } else {
      _radioLogger.finer(
        "Radio cache still contained enough items (${localResult.tracks.length}), sourcing from there.",
      );
    }
    final tracksToAddCount = min(switch (localResult.radioMode) {
      RadioMode.albumMix => localResult.tracks.length, // album mix returns full albums, and those should stay together
      _ => radioTracksNeeded,
    }, localResult.tracks.length);
    final tracksToAdd = localResult.tracks.take(tracksToAddCount);
    final tracksToCache = localResult.tracks.skip(tracksToAddCount);
    // Check if we have been invalidated while generating
    if (identical(localResult, _radioCacheStateStream.value)) {
      if (tracksToAdd.isEmpty) {
        _radioLogger.warning("No tracks generated for radio. Aborting.");
        localResult = localResult.copyWith(generating: false, failed: true);
        _radioCacheStateStream.add(localResult);
        return;
      } else {
        if (localResult.isStillValid()) {
          localResult = localResult.copyWith(
            seedItem: localResult.radioMode == RadioMode.continuous
                ? tracksToAdd.lastOrNull ?? localResult.seedItem
                : null,
            generating: false,
            queueing: true,
            failed: false,
          );
          _radioCacheStateStream.add(localResult);
          await queueService.addToQueue(
            BasePlayableSlice(
              items: tracksToAdd.toList(),
              startingIndex: 0,
              source: QueueItemSource.rawId(
                type: QueueItemSourceType.radio,
                name: currentQueue.source.item != null
                    ? QueueItemSourceName(
                        type: QueueItemSourceNameType.radio,
                        localizationParameter: currentQueue.source.item?.name ?? "",
                      )
                    : QueueItemSourceName(type: QueueItemSourceNameType.radio),
                id: currentQueue.source.item?.id.raw ?? currentQueue.source.id,
              ),
              shuffleState: SliceShuffleState.linear,
            ),
          );
          _radioLogger.finer(
            "Added ${tracksToAdd.map((song) => song.name).toList().join(", ")} to the queue for radio.",
          );
          // Check if we have been invalidated while adding tracks to queue
          if (identical(localResult, _radioCacheStateStream.value)) {
            _radioCacheStateStream.add(localResult.copyWith(tracks: tracksToCache.toList(), queueing: false));
          }
        }
      }
    }
  }
}

Future<void> startRadioPlayback(BaseItemDto source) async {
  final currentRadioMode = FinampSettingsHelper.finampSettings.radioMode;
  final int radioTracksNeededForInitialQueue = switch (currentRadioMode) {
    // continuous mode requires successive requests, so reduce the amount of tracks so the queue starts faster
    // additional tracks will be loaded after the queue has started
    RadioMode.continuous => 3,
    // if we find true albums right away, this threshold should be easily surpassed
    // if not, searching for fallbacks could take a few requests, so accept fewer tracks to start the queue, then delegate further loading
    RadioMode.albumMix => 7,
    _ => 30,
  };

  invalidateRadioCache(); // we're starting a new queue, any older state is invalid now
  var localResult = _radioCacheStateStream.value!.copyWith(generating: true, failed: false);
  _radioCacheStateStream.add(localResult);

  List<BaseItemDto> generatedTracks = [];
  try {
    generatedTracks = await generateRadioTracks(
      radioTracksNeededForInitialQueue,
      overrideSeedItem: source,
      forNewQueue: true,
    );
  } catch (e) {
    _radioLogger.warning("Couldn't generate radio tracks: $e");
  }

  final tracksToAddCount = min(switch (localResult.radioMode) {
    RadioMode.albumMix => generatedTracks.length, // album mix returns full albums, and those should stay together
    RadioMode.reshuffle => generatedTracks.length, // we append the full shuffled source at once
    _ => radioTracksNeededForInitialQueue,
  }, generatedTracks.length);
  final tracksToAdd = generatedTracks.take(tracksToAddCount);
  final tracksToCache = generatedTracks.skip(tracksToAddCount);

  if (tracksToAdd.isEmpty) {
    _radioLogger.warning("No tracks generated for radio playback from source '${source.name}'. Aborting.");
    GlobalSnackbar.message((context) => AppLocalizations.of(context)!.radioNoTracksFound);
    return;
  }

  FinampSetters.setRadioMode(currentRadioMode);
  toggleRadio(true);
  invalidateRadioCache(); // we're still starting a new queue, and acquire a new lock here
  localResult = _radioCacheStateStream.value!.copyWith(
    generating: false,
    queueing: true,
    seedItem: currentRadioMode == RadioMode.continuous ? tracksToAdd.lastOrNull ?? source : source,
    tracks: tracksToCache.toList(),
  );
  _radioCacheStateStream.add(localResult);

  await GetIt.instance<QueueService>().startPlayback(
    items: tracksToAdd.toList(),
    source: QueueItemSource.fromBaseItem(source),
    customTrackSource: QueueItemSource(
      type: QueueItemSourceType.radio,
      name: QueueItemSourceName(type: QueueItemSourceNameType.radio, localizationParameter: source.name ?? ""),
      id: source.id,
      item: source,
    ),
    skipRadioCacheInvalidation: true,
  );

  if (identical(localResult, _radioCacheStateStream.value)) {
    _radioCacheStateStream.add(localResult.copyWith(queueing: false));
  }
}

void invalidateRadioCache() {
  final radioMode = FinampSettingsHelper.finampSettings.radioMode;
  final radioState = FinampSettingsHelper.finampSettings.radioEnabled;
  final providers = GetIt.instance<ProviderContainer>();
  _radioLogger.info("Invalidating radio cache.");
  _radioCacheStateStream.add(
    RadioCacheState(
      tracks: [],
      radioMode: radioMode,
      seedItem: providers.read(getActiveRadioSeedProvider(radioMode)),
      radioState: radioState,
    ),
  );
  _radioCallTimestamps.clear();
}

bool toggleRadio([bool? enable]) {
  final queueService = GetIt.instance<QueueService>();
  final currentlyEnabled = FinampSettingsHelper.finampSettings.radioEnabled;
  final radioNowEnabled = enable ?? !currentlyEnabled;
  FinampSetters.setRadioEnabled(radioNowEnabled);
  // trigger a loop mode update to configure the player correctly
  // since for the radio we override the player loop mode
  queueService.loopMode = queueService.loopMode;
  if (!radioNowEnabled) {
    unawaited(queueService.clearRadioTracks());
  }
  GetIt.instance<MusicPlayerBackgroundTask>().refreshPlaybackStateAndMediaNotification();
  return radioNowEnabled;
}

/// Callers should set up correct radio state synchronously before calling this,
/// so that we will be ready for the radio to restart as soon as this function releases its lock.
Future<void> withRadioLock(Future<void> Function() action) async {
  invalidateRadioCache();
  var localResult = _radioCacheStateStream.value!.copyWith(queueing: true);
  _radioCacheStateStream.add(localResult);
  await action();
  if (identical(localResult, _radioCacheStateStream.value)) {
    _radioCacheStateStream.add(localResult.copyWith(queueing: false));
  }
}

// Generates tracks for the radio. Provide item to generate the initial radio tracks.
Future<List<BaseItemDto>> generateRadioTracks(
  int minNumTracks, {
  BaseItemDto? overrideSeedItem,
  List<BaseItemDto> cachedTracks = const [],
  bool forNewQueue = false,
}) async {
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final downloadsService = GetIt.instance<DownloadsService>();
  final finampUserHelper = GetIt.instance<FinampUserHelper>();
  final queueService = GetIt.instance<QueueService>();
  final providers = GetIt.instance<ProviderContainer>();
  final currentQueue = queueService.getQueue();
  List<BaseItemDto> tracksOut = [];

  assert(
    currentQueue.fullQueue.isNotEmpty || overrideSeedItem != null,
    "overrideSeedItem must be provided if the queue is empty.",
  );

  final actualSeed =
      overrideSeedItem ?? providers.read(getActiveRadioSeedProvider(FinampSettingsHelper.finampSettings.radioMode));

  _radioLogger.finer(
    "Generating $minNumTracks radio tracks from ${overrideSeedItem == null ? "queue" : "override"} item '${actualSeed?.name}' using '${FinampSettingsHelper.finampSettings.radioMode.name}' mode.",
  );

  /// Adds tracks in such a manner to simulate "shuffle-repeat all",
  /// but with each repeat iteration re-shuffling the order.
  Future<List<BaseItemDto>> reshuffleMode() async {
    final reshuffleModeAvailabilityStatus = providers.read(
      _randomAndReshuffleRadioModeAvailabilityStatusProvider(overrideSeedItem),
    );
    if (!reshuffleModeAvailabilityStatus.isAvailable) {
      throw Exception(
        "Reshuffle radio mode selected but the provided item '${overrideSeedItem?.name}' not downloaded or the queue is empty. Availability status: $reshuffleModeAvailabilityStatus. Returning empty track list.",
      );
    }
    final queueWithoutRadioTracks = currentQueue.fullQueue
        .whereNot((e) => e.source.type == QueueItemSourceType.radio)
        .toList();
    // Items originally in the currently playing source (or manually added)
    final originalQueue =
        (actualSeed != null
                ? (await loadChildTracksFromBaseItem(
                    item: actualSeed,
                    sortConfig: SortAndFilterConfiguration.defaultForItem(actualSeed),
                  )).map((item) => item).toList()
                : <BaseItemDto>[])
            // if the queue is purely made up of radio modes (i.e. after using the "Start Radio" option in the menu), we don't filter out radio tracks
            .followedBy(
              (forNewQueue ? <FinampQueueItem>[] : queueWithoutRadioTracks)
                  .where(
                    (e) => !FinampSettingsHelper.finampSettings.isOffline || e.item.extras?["isDownloaded"] == true,
                  )
                  .map((e) => e.baseItem)
                  .nonNulls,
            )
            .toList();
    if (originalQueue.isEmpty) {
      throw Exception(
        "Reshuffle radio mode selected but no valid tracks found in the current queue or from the provided seed item '${actualSeed?.name}'.",
      );
    }
    return originalQueue.shuffled();
  }

  /// Adds tracks from the source completely randomly,
  /// even allowing the same track to repeat
  Future<List<BaseItemDto>> randomMode() async {
    final randomModeAvailabilityStatus = providers.read(
      _randomAndReshuffleRadioModeAvailabilityStatusProvider(overrideSeedItem),
    );
    if (!randomModeAvailabilityStatus.isAvailable) {
      throw Exception(
        "Random radio mode selected but the provided item '${overrideSeedItem?.name}' is not downloaded or the queue is empty. Availability status: $randomModeAvailabilityStatus. Returning empty track list.",
      );
    }
    final queueWithoutRadioTracks = currentQueue.fullQueue
        .whereNot((e) => e.source.type == QueueItemSourceType.radio)
        .toList();
    // Items originally in the currently playing source (or manually added)
    final originalQueue =
        (actualSeed != null
                ? (await loadChildTracksFromBaseItem(
                    item: actualSeed,
                    sortConfig: SortAndFilterConfiguration.defaultForItem(actualSeed),
                  )).map((item) => item).toList()
                : <BaseItemDto>[])
            // if the queue is purely made up of radio modes (i.e. after using the "Start Radio" option in the menu), we don't filter out radio tracks
            .followedBy(
              (forNewQueue ? <FinampQueueItem>[] : queueWithoutRadioTracks)
                  .where(
                    (e) => !FinampSettingsHelper.finampSettings.isOffline || e.item.extras?["isDownloaded"] == true,
                  )
                  .map((e) => e.baseItem)
                  .nonNulls,
            )
            .toList();
    return List.generate(max(25, minNumTracks), (index) {
      // Pick a random item to add, duplicates possible!
      int nextIndex = _radioRandom.nextInt(originalQueue.length);
      return originalQueue[nextIndex];
    });
  }

  /// Adds tracks which are similar to the queue source, with a slightly randomized order
  /// Filters out any duplicates
  Future<List<BaseItemDto>> similarMode() async {
    if (actualSeed == null) {
      throw Exception("No seed item available for radio generation. Aborting.");
    }
    // extra tracks to randomly choose from to introduce non-determinism
    final randomnessExtraTracks = 8 + (minNumTracks * 0.5).ceil();
    return await _getSimilarTracks(
      referenceItem: actualSeed,
      minNumTracks: minNumTracks,
      additionalExistingTracks: cachedTracks,
      randomnessExtraTracks: randomnessExtraTracks,
      maxAttempts: 10,
      // filter out ALL duplicates, otherwise things will start repeating too often
      // since the base item never changes
      repetitionThresholdTracks: currentQueue.trackCount,
      // don't use old queue to filter out tracks if we're starting a new queue
      disableDuplicateFiltering: forNewQueue,
    );
  }

  /// Like [RadioMode.similar], but based on the last track in the queue, not the original source
  Future<List<BaseItemDto>> continuousMode() async {
    if (actualSeed == null) {
      throw Exception("No seed item available for radio generation. Aborting.");
    }
    // extra tracks to randomly choose from to introduce non-determinism
    final randomnessExtraTracks = 5 + (minNumTracks * 1.5).ceil();

    List<BaseItemDto> continuousTracks = [actualSeed];
    // we fetch tracks one-by-one to be truly continuous from the start. for that we use the while loop and only ever fetch a single track at a time.
    while (continuousTracks.length < minNumTracks + 1) {
      final continuousTracksSample = await _getSimilarTracks(
        // use the last track as the reference so that the radio flows better
        // if we use the current tracks it always alternates between similar tracks because there's a delay of [minUpcomingRadioTracks] before the related track is played
        // [seedItem] is only used for generating tracks if there's no queue yet
        referenceItem: continuousTracks.last,
        minNumTracks: 1,
        additionalExistingTracks: cachedTracks + continuousTracks,
        maxAttempts: 10,
        randomnessExtraTracks: randomnessExtraTracks,
        // filter out recent tracks within 90 minutes
        repetitionThresholdTracks: currentQueue.getTrackCountWithinDuration(Duration(minutes: 90)),
        // don't use old queue to filter out tracks if we're starting a new queue
        disableDuplicateFiltering: forNewQueue,
      );
      if (continuousTracksSample.isEmpty) {
        _radioLogger.warning("Failed to find similar track to ${continuousTracks.last.name}. Aborting.");
        break;
      } else {
        continuousTracks.add(continuousTracksSample.first);
      }
    }
    // remove actualSeed from list start
    continuousTracks.removeAt(0);
    return continuousTracks;
  }

  Future<List<BaseItemDto>> albumMixMode() async {
    int attempt = 0;

    RadioCacheState? localRadioState = _radioCacheStateStream.valueOrNull;
    AlbumMixFallbackModes? fallbackMode;
    if (overrideSeedItem == null) {
      assert(actualSeed == localRadioState?.seedItem, "Inconsistent seed item state in album mix radio generation.");
      fallbackMode = localRadioState?.albumMixFallbackMode;
    }
    if (fallbackMode == null && FinampSettingsHelper.finampSettings.isOffline) {
      fallbackMode = AlbumMixFallbackModes.artistAlbums;
    }

    try {
      if (actualSeed == null) {
        throw Exception("No seed item available for radio generation. Aborting.");
      }
      final seedId = getAlbumMixRadioModeSeedId(actualSeed);
      if (seedId == null) {
        throw Exception(
          "Album mix radio mode selected but the provided item '${actualSeed.name}' is not suitable for album mix radio. Returning empty track list.",
        );
      }
      // extra albums in case duplicates are removed
      const filterExtraAlbums = 10;
      // extra albums to randomly choose from to introduce non-determinism
      final randomnessExtraAlbums = 5;

      // filter out any albums where tracks with that album as the (radio) source are already in the queue
      final existingAlbumIds = currentQueue.fullQueue
          .where((queueItem) => queueItem.baseItem.albumId != null)
          .map((queueItem) => queueItem.baseItem.albumId)
          .toSet();
      List<BaseItemDto> filteredSimilarAlbums = [];

      while (filteredSimilarAlbums.isEmpty) {
        final additionalAlbums = 2 * attempt + pow(attempt, 2.75).toInt(); // ~ 0, 3, 10, 27, 50, 100
        attempt++;
        if (attempt > 1) {
          _radioLogger.warning("No similar albums found. Retrying with $additionalAlbums extra albums.");
        }

        List<BaseItemDto> similarAlbums;

        switch (fallbackMode) {
          case AlbumMixFallbackModes.artistAlbums:
          case AlbumMixFallbackModes.artistSingles:
          case AlbumMixFallbackModes.performingArtistAlbums:
            BaseItemDto? artist;
            List<BaseItemId> artistIds = [];
            if (fallbackMode != AlbumMixFallbackModes.performingArtistAlbums) {
              artistIds.addAll(actualSeed.albumArtists?.map((e) => e.id).whereType<BaseItemId>() ?? []);
            }
            artistIds.addAll(actualSeed.artistItems?.map((e) => e.id).whereType<BaseItemId>() ?? []);
            while (artist == null && artistIds.isNotEmpty) {
              final artistId = artistIds.removeAt(0);
              artist = await providers.read(artistItemProvider(artistId).future);
            }
            if (artist == null) {
              fallbackMode = AlbumMixFallbackModes.libraryAlbumsOrSingles;
              continue;
            }
            if (fallbackMode == AlbumMixFallbackModes.performingArtistAlbums) {
              similarAlbums = await providers.read(
                getPerformingArtistAlbumsProvider(
                  artist: artist,
                  libraryFilter: currentQueue.sourceLibrary?.id,
                  sortBy: SortBy.random,
                ).future,
              );
            } else {
              similarAlbums = await providers.read(
                getArtistAlbumsProvider(
                  artist: artist,
                  libraryFilter: currentQueue.sourceLibrary?.id,
                  sortBy: SortBy.random,
                ).future,
              );
            }

            break;
          case AlbumMixFallbackModes.libraryAlbumsOrSingles:
            // just fetch a random album from the library
            if (FinampSettingsHelper.finampSettings.isOffline) {
              similarAlbums = (await downloadsService.getAllCollections(
                includeItemTypes: [BaseItemDtoType.album],
                fullyDownloaded: false,
                viewFilter: finampUserHelper.currentUser?.currentViewId,
                nullableViewFilters: FinampSettingsHelper.finampSettings.showDownloadsWithUnknownLibrary,
              )).map((e) => e.baseItem).nonNulls.toList();
            } else {
              similarAlbums =
                  (await jellyfinApiHelper.getItems(
                    parentItem: currentQueue.sourceLibrary,
                    recursive: true,
                    includeItemTypes: [BaseItemDtoType.album.name].join(","),
                    sortBy: SortBy.random.jellyfinName(ContentType.albums),
                  )) ??
                  [];
            }
            break;
          case AlbumMixFallbackModes.similarSingles:
          case null:
            if (FinampSettingsHelper.finampSettings.isOffline) {
              fallbackMode = AlbumMixFallbackModes.artistAlbums;
              continue;
            }
            similarAlbums =
                await jellyfinApiHelper.getSimilarAlbums(
                  seedId,
                  limit: 1 + filterExtraAlbums + randomnessExtraAlbums + additionalAlbums,
                ) ??
                [];
            break;
        }

        if (similarAlbums.isEmpty && fallbackMode == null) {
          // Jellyfin can't guarantee that there are similar albums, since the suggestions are based on genre tags
          // If a genre only contains that one album, no similar albums will be returned
          _radioLogger.warning(
            "No new similar albums found for album mix radio from item '${actualSeed.name}'. Fetching based on album artist.",
          );
          fallbackMode = AlbumMixFallbackModes.artistAlbums;
          continue;
        }

        filteredSimilarAlbums = similarAlbums
            .where((album) => !existingAlbumIds.contains(album.id))
            // don't include singles unless we're falling back to them
            .where(
              (album) =>
                  ([
                    AlbumMixFallbackModes.similarSingles,
                    AlbumMixFallbackModes.artistSingles,
                    AlbumMixFallbackModes.libraryAlbumsOrSingles,
                  ].contains(fallbackMode) ||
                  (album.songCount ?? album.childCount ?? 0) > 1),
            )
            .toList();

        if (filteredSimilarAlbums.isEmpty) {
          switch (fallbackMode) {
            case AlbumMixFallbackModes.artistAlbums:
              _radioLogger.warning(
                "No suitable similar full albums found for album mix radio from artist '${actualSeed.albumArtists?.first.name ?? actualSeed.artistItems?.first.name}'. Fetching singles.",
              );
              fallbackMode = AlbumMixFallbackModes.artistSingles;
              continue;
            case AlbumMixFallbackModes.artistSingles:
              _radioLogger.warning(
                "No suitable similar singles found for album mix radio from artist '${actualSeed.albumArtists?.first.name ?? actualSeed.artistItems?.first.name}'. Fetching appears on albums.",
              );
              fallbackMode = AlbumMixFallbackModes.performingArtistAlbums;
              continue;
            case AlbumMixFallbackModes.performingArtistAlbums:
              _radioLogger.warning(
                "No suitable similar appears on albums found for album mix radio from artist '${actualSeed.albumArtists?.first.name ?? actualSeed.artistItems?.first.name}'. Fetching from library.",
              );
              fallbackMode = AlbumMixFallbackModes.libraryAlbumsOrSingles;
              continue;
            case AlbumMixFallbackModes.similarSingles:
            case AlbumMixFallbackModes.libraryAlbumsOrSingles:
              break;
            case null:
              if (attempt >= 5) {
                _radioLogger.warning(
                  "No new suitable similar albums found for album mix radio for item '${actualSeed.name}' after $attempt attempts. Switching to fallbacks",
                );
                fallbackMode = AlbumMixFallbackModes.artistAlbums;
              }
              break;
          }
        }
      }

      // pick a random album from the remaining ones
      if (filteredSimilarAlbums.isNotEmpty) {
        BaseItemDto selectedAlbum;
        if (fallbackMode == AlbumMixFallbackModes.libraryAlbumsOrSingles) {
          // since we can't filter by track count when fetching from the server, we instead sort by track count > 1 to pick a full album if available, but fall back to singles
          filteredSimilarAlbums.sortBy<num>((album) => (album.songCount ?? album.childCount ?? 0) > 1 ? 0 : 1);
          selectedAlbum = filteredSimilarAlbums.first;
          filteredSimilarAlbums.removeAt(0);
        } else {
          final randomIndex = _radioRandom.nextInt(min(filteredSimilarAlbums.length, randomnessExtraAlbums));
          selectedAlbum = filteredSimilarAlbums[randomIndex];
          filteredSimilarAlbums.removeAt(randomIndex);
        }
        _radioLogger.finer("Selected album '${selectedAlbum.name}' for album mix radio.");
        // load tracks from the selected album
        final albumTracks = await loadChildTracksFromBaseItem(
          item: selectedAlbum,
          sortConfig: SortAndFilterConfiguration.defaultForItem(selectedAlbum),
        );
        // we add all tracks at once to preserve the album as a unit
        return albumTracks;
      } else {
        throw Exception("No suitable similar albums found for album mix radio. Returning empty track list.");
      }
    } catch (e) {
      rethrow;
    } finally {
      // if it's a regular radio track generation, update the fallback mode for the current cache state
      // if the cache gets replaced/invalidated before we get here, we only end up modifying the old cache state which isn't used anymore
      if (localRadioState != null && overrideSeedItem == null) {
        localRadioState.updateAlbumMixFallbackMode(fallbackMode);
      }
    }
  }

  try {
    tracksOut = switch (FinampSettingsHelper.finampSettings.radioMode) {
      RadioMode.reshuffle => await reshuffleMode(),
      RadioMode.random => await randomMode(),
      RadioMode.similar => await similarMode(),
      RadioMode.continuous => await continuousMode(),
      RadioMode.albumMix => await albumMixMode(),
    };
  } catch (e) {
    _radioLogger.warning(e);
  }
  _radioLogger.finer(
    "Selected ${tracksOut.length} tracks for '${FinampSettingsHelper.finampSettings.radioMode.name}' mode: ${tracksOut.map((e) => "'${e.artists?.firstOrNull} - ${e.name}'").join(", ")}",
  );
  return tracksOut;
}

Future<List<BaseItemDto>> _getSimilarTracks({
  required BaseItemDto referenceItem,
  required int minNumTracks,
  required List<BaseItemDto> additionalExistingTracks,
  required int randomnessExtraTracks,
  required int repetitionThresholdTracks,
  required int maxAttempts,
  bool disableDuplicateFiltering = false,
}) async {
  const skippedTracks = 1; // extra track to exclude the current track
  const filterExtraTracks = 10; // extra tracks in case duplicates are removed

  assert(!FinampSettingsHelper.finampSettings.isOffline, "Similar tracks not available while offline");
  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final queueService = GetIt.instance<QueueService>();
  int attempt = 0;
  while (attempt < maxAttempts) {
    final attemptExtraTracks = 2 * attempt + pow(attempt, 2.75).toInt(); // ~ 0, 3, 10, 27, 50, 100, ...
    if (attempt > 0) {
      _radioLogger.warning("No similar tracks found. Retrying with $attemptExtraTracks extra tracks.");
    }
    attempt++;

    final trackLimit = minNumTracks + skippedTracks + filterExtraTracks + randomnessExtraTracks + attemptExtraTracks;
    _radioLogger.finer("Fetching (up to) $trackLimit similar tracks for reference item '${referenceItem.name}'.");

    final items = await jellyfinApiHelper.getInstantMix(referenceItem, limit: trackLimit);
    List<BaseItemDto> filteredSample = [];
    if (items != null) {
      filteredSample.addAll(items);
      _radioLogger.finer(
        "Fetched ${filteredSample.length} similar radio candidates: ${filteredSample.map((e) => "'${e.artists?.firstOrNull} - ${e.name}'").join(", ")}",
      );
      // instant mixes always return the track itself as the first item, filter it out
      // this will also work with [skippedTracks] > 1, emulating a [startIndex] parameter
      filteredSample.removeRange(0, min(skippedTracks, filteredSample.length));
      final originalTrackCount = filteredSample.length;
      // filter out duplicate tracks, including upcoming ones
      final recentlyPlayedIds =
          (disableDuplicateFiltering
                  ? <BaseItemDto>[]
                  : queueService
                        .getQueue()
                        .fullQueue
                        .reversed
                        .take(repetitionThresholdTracks)
                        .map((item) => item.baseItem))
              .followedBy(additionalExistingTracks)
              .map((item) => item.id)
              .toSet();
      filteredSample.removeWhere((item) => recentlyPlayedIds.contains(item.id));
      final filteredOutTrackCount = originalTrackCount - filteredSample.length;
      // we requested more tracks in case of duplicates, but if those are not needed we want to stay as similar as possible, since we already have some overhead for randomness
      final trimAmount = max(
        0,
        min(
          min(
            filteredOutTrackCount,
            // ensure we only trim up to [filterExtraTracks] to not remove too many candidates
            filterExtraTracks,
          ),
          filteredSample.length - minNumTracks,
        ),
      );
      filteredSample.removeRange(filteredSample.length - trimAmount, filteredSample.length);
      _radioLogger.finer(
        "Filtered candidates (${filteredSample.length}): ${filteredSample.map((e) => "'${e.artists?.firstOrNull} - ${e.name}'").join(", ")}",
      );
      // pick a random subset of tracks to ensure non-determinism
      filteredSample = filteredSample.shuffled();
    }
    if (filteredSample.length >= minNumTracks) {
      return filteredSample;
    }
  }
  throw Exception("No similar tracks found in ${maxAttempts + 1} attempts. Aborting.");
}

enum RadioModeAvailabilityStatus {
  disabled,
  available,
  unavailableOffline,
  unavailableNotDownloaded,
  unavailableSourceTypeNotSupported,
  unavailableQueueEmpty,
  unavailableSourceNull;

  bool get isAvailable => this == RadioModeAvailabilityStatus.available;
}

final currentRadioAvailabilityStatusProvider = Provider<RadioModeAvailabilityStatus>((ref) {
  final radioMode = ref.watch(finampSettingsProvider.radioMode);
  final radioModeAvailable = ref.watch(
    radioModeAvailabilityStatusProvider((radioMode, ref.watch(getActiveRadioSeedProvider(radioMode)))),
  );
  final radioEnabled = ref.watch(finampSettingsProvider.radioEnabled);
  return !radioEnabled ? RadioModeAvailabilityStatus.disabled : radioModeAvailable;
});

final radioModeAvailabilityStatusProvider =
    AutoDisposeProviderFamily<RadioModeAvailabilityStatus, (RadioMode, BaseItemDto?)>((
      ref,
      (RadioMode radioMode, BaseItemDto? source) arguments,
    ) {
      final radioMode = arguments.$1;
      final source = arguments.$2;

      final randomAndReshuffleModeAvailability = ref.watch(
        _randomAndReshuffleRadioModeAvailabilityStatusProvider(source),
      );
      final similarAndContinuousModeAvailability = ref.watch(
        _similarAndContinuousRadioModeAvailabilityStatusProvider(source),
      );
      final albumMixModeAvailable = ref.watch(_albumMixRadioModeAvailabilityStatusProvider(source));

      final currentModeAvailable = switch (radioMode) {
        RadioMode.random || RadioMode.reshuffle => randomAndReshuffleModeAvailability,
        RadioMode.similar || RadioMode.continuous => similarAndContinuousModeAvailability,
        RadioMode.albumMix => albumMixModeAvailable,
      };
      return currentModeAvailable;
    });

final _randomAndReshuffleRadioModeAvailabilityStatusProvider =
    ProviderFamily<RadioModeAvailabilityStatus, BaseItemDto?>((ref, BaseItemDto? baseItem) {
      if (baseItem != null) {
        final downloadsService = GetIt.instance<DownloadsService>();

        // only available offline when downloaded
        return (!ref.watch(finampSettingsProvider.isOffline) ||
                ref
                    .watch(
                      downloadsService.statusProvider((
                        DownloadStub.fromItem(type: baseItem.downloadType, item: baseItem),
                        null,
                      )),
                    )
                    .isDownloaded)
            ? RadioModeAvailabilityStatus.available
            : RadioModeAvailabilityStatus.unavailableNotDownloaded;
      } else {
        return ref.watch(QueueService.queueProvider.select((x) => (x?.trackCount ?? 0) > 0))
            ? RadioModeAvailabilityStatus.available
            : RadioModeAvailabilityStatus.unavailableQueueEmpty;
      }
    });

final _similarAndContinuousRadioModeAvailabilityStatusProvider =
    ProviderFamily<RadioModeAvailabilityStatus, BaseItemDto?>((ref, BaseItemDto? baseItem) {
      // only available online when source is not null
      return ref.watch(finampSettingsProvider.isOffline)
          ? RadioModeAvailabilityStatus.unavailableOffline
          : baseItem == null
          ? RadioModeAvailabilityStatus.unavailableSourceNull
          : RadioModeAvailabilityStatus.available;
    });

BaseItemId? getAlbumMixRadioModeSeedId(BaseItemDto? baseItem) {
  return baseItem != null
      ? switch (BaseItemDtoType.fromItem(baseItem)) {
          BaseItemDtoType.album => baseItem.id,
          BaseItemDtoType.track => baseItem.albumId,
          _ => null,
        }
      : null;
}

final _albumMixRadioModeAvailabilityStatusProvider = ProviderFamily<RadioModeAvailabilityStatus, BaseItemDto?>((
  ref,
  BaseItemDto? baseItem,
) {
  // only when the seed item is an album itself or part of one
  final albumMixModeAvailable = getAlbumMixRadioModeSeedId(baseItem) != null;
  return albumMixModeAvailable
      ? RadioModeAvailabilityStatus.available
      : RadioModeAvailabilityStatus.unavailableSourceTypeNotSupported;
});

final getActiveRadioSeedProvider = ProviderFamily<BaseItemDto?, RadioMode>((Ref ref, RadioMode radioMode) {
  final currentQueue = ref.watch(QueueService.queueProvider);
  switch (radioMode) {
    case RadioMode.continuous:
      return currentQueue?.fullQueue.lastOrNull?.baseItem;
    case RadioMode.reshuffle:
    case RadioMode.random:
      return currentQueue?.source.type == QueueItemSourceType.radio ? currentQueue?.source.item : null;
    case RadioMode.similar:
    case RadioMode.albumMix:
      return currentQueue?.source.item;
  }
});

IconData getRadioModeIcon(RadioMode radioMode) {
  return switch (radioMode) {
    RadioMode.reshuffle => TablerIcons.arrows_shuffle,
    RadioMode.random => TablerIcons.help_hexagon,
    RadioMode.similar => TablerIcons.ear,
    RadioMode.continuous => TablerIcons.route,
    RadioMode.albumMix => TablerIcons.album,
  };
}
