import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

import 'music_player_background_task.dart';

class ProgressState {
  final MediaItem? mediaItem;
  final PlaybackState playbackState;
  final Duration position;

  ProgressState(this.mediaItem, this.playbackState, this.position);
}

/// Encapsulate all the different data we're interested in into a single
/// stream so we don't have to nest StreamBuilders.
Stream<ProgressState> get progressStateStream {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  return Rx.combineLatest3<MediaItem?, PlaybackState, Duration, ProgressState>(
    audioHandler.mediaItem,
    audioHandler.playbackState,
    AudioService.position.startWith(audioHandler.playbackState.value.position),
    (mediaItem, playbackState, position) => ProgressState(mediaItem, playbackState, position),
  );
}

ProgressState? get progressState {
  final audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
  return ProgressState(
    audioHandler.mediaItem.value,
    audioHandler.playbackState.value,
    audioHandler.playbackState.value.position,
  );
}
