import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'album_image_provider.dart';

/// Provider to handle syncing up the current playing item's image provider.
/// Used on the player screen to sync up loading the blurred background.
/// Use ListenableImage as output to allow directly overriding localImageProvider
final currentAlbumImageProvider = Provider<FinampImage>((ref) {
  final List<FinampQueueItem> precacheItems = GetIt.instance<QueueService>().peekQueue(
    next: 3,
    previous: 1,
    current: true,
  );
  for (final itemToPrecache in precacheItems) {
    BaseItemDto? base = itemToPrecache.baseItem;
    if (base != null) {
      final request = AlbumImageRequest(item: base);
      // full quality player images are cached immediately upon albumImageProvider creation, so we don't need to
      // resolve the provider like we would to initiate caching with a NetworkImage
      ref.listen(albumImageProvider(request), (_, latest) {});
      // TODO maybe we still want to resolve the images to make sure the decoded image is already in memory?
      /*var image = ref.watch(albumImageProvider(request)).image;
      if (image != null) {
        // Cache the returned image
        var stream = image.resolve(const ImageConfiguration(devicePixelRatio: 1.0));
        var listener = ImageStreamListener((image, synchronousCall) {});
        ref.onDispose(() {
          stream.removeListener(listener);
        });
        stream.addListener(listener);
      }*/
    }
  }

  final currentTrack = ref.watch(currentTrackProvider).value?.baseItem;
  if (currentTrack != null) {
    final request = AlbumImageRequest(item: currentTrack);
    // Setting useIsolate to false provides negligible speedup for player images and induces lag, so use true.
    final albumImage = ref.watch(albumImageProvider(request));
    assert(albumImage.fullQuality);
    return albumImage.asTheme(ThemeInfo(currentTrack, useIsolate: true));
  }
  return FinampImage.empty();
});

final currentTrackProvider = StreamProvider((_) => GetIt.instance<QueueService>().getCurrentTrackStream());
