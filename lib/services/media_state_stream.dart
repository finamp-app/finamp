import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import 'music_player_background_task.dart';

class MediaState {
  final MediaItem? mediaItem;
  final PlaybackState playbackState;
  final FadeState fadeState;

  MediaState(this.mediaItem, this.playbackState, this.fadeState);
}

/// A stream reporting the combined state of the current media item and its
/// current position.
Stream<MediaState> get mediaStateStream {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  return Rx.combineLatest3<MediaItem?, PlaybackState, FadeState, MediaState>(
    audioHandler.mediaItem,
    audioHandler.playbackState,
    audioHandler.fadeState,
    (mediaItem, playbackState, fadeState) => MediaState(mediaItem, playbackState, fadeState),
  );
}

final mediaStateProvider = StreamProvider.autoDispose<MediaState>((_) => mediaStateStream).select((v) {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  return v.valueOrNull ??
      MediaState(audioHandler.mediaItem.valueOrNull, audioHandler.playbackState.value, audioHandler.fadeState.value);
});
