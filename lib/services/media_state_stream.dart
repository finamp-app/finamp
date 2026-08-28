import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import 'music_player_background_task.dart';

class MediaState {
  final MediaItem? mediaItem;
  final PlaybackState playbackState;
  final FadeDirection fadeDirection;

  MediaState(this.mediaItem, this.playbackState, this.fadeDirection);
}

/// A stream reporting the combined state of the current media item and its
/// current position.
Stream<MediaState> get mediaStateStream {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  return Rx.combineLatest3<MediaItem?, PlaybackState, FadeDirection, MediaState>(
    audioHandler.mediaItem,
    audioHandler.playbackState,
    audioHandler.fadeState.map((x) => x.fadeDirection).distinct(),
    (mediaItem, playbackState, fadeState) => MediaState(mediaItem, playbackState, fadeState),
  );
}

final mediaStateProvider = StreamProvider.autoDispose<MediaState>((_) => mediaStateStream).select((v) {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  return v.valueOrNull ??
      MediaState(
        audioHandler.mediaItem.valueOrNull,
        audioHandler.playbackState.value,
        audioHandler.fadeState.value.fadeDirection,
      );
});
