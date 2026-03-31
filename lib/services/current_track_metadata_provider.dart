import 'package:audio_service/audio_service.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'metadata_provider.dart';

/// Provider to handle pre-fetching metadata for upcoming tracks
final currentTrackMetadataProvider = AutoDisposeProvider<AsyncValue<MetadataProvider?>>((ref) {
  final List<FinampQueueItem> precacheItems = GetIt.instance<QueueService>().peekQueue(
    next: 3,
    previous: 1,
    current: true,
  );
  for (final itemToPrecache in precacheItems) {
    BaseItemDto? base = itemToPrecache.baseItem;
    if (base != null) {
      ref.listen(metadataProvider(base), (_, __) {});
      ref.read(
        metadataProvider(base),
      ); // forces it even in background https://github.com/rrousselGit/riverpod/issues/2671
    }
  }

  final currentTrack = ref.watch(currentTrackProvider).value;
  if (currentTrack?.baseItem != null) {
    return ref.watch(metadataProvider(currentTrack!.baseItem!));
  }
  return const AsyncValue.data(null);
});

final currentTrackProvider = StreamProvider((_) => GetIt.instance<QueueService>().getCurrentTrackStream());

/// Streams the currently-playing [MediaItem] from the audio handler, including
/// any chapter data injected after extraction. Riverpod will rebuild consumers
/// whenever chapters (or anything else) on the current item change.
final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return GetIt.instance<MusicPlayerBackgroundTask>().mediaItem;
});
