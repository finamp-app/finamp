import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:flutter/cupertino.dart' hide RepeatMode;
import 'package:smtc_windows/smtc_windows.dart';

class AudioServiceSMTC extends AudioServicePlatform {
  AudioHandlerCallbacks? _handlerCallbacks;
  late SMTCWindows smtc;

  static void registerWith() {
    AudioServicePlatform.instance = AudioServiceSMTC();
  }

  @override
  Future<void> configure(ConfigureRequest request) async {
    // initialize SMTC
    //TODO we should call smtc.dispose() before the app is closed to prevent a background process from continuing to run
    // https://pub.dev/packages/flutter_window_close could be used to detect when the app is closed
    await SMTCWindows.initialize();
    smtc = SMTCWindows(
      // Which buttons to show in the OS media player
      config: const SMTCConfig(
        fastForwardEnabled: true,
        nextEnabled: true,
        pauseEnabled: true,
        playEnabled: true,
        rewindEnabled: true,
        prevEnabled: true,
        stopEnabled: true,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Listen to button events and update playback status accordingly
        smtc.buttonPressStream.listen((PressedButton event) async {
          switch (event) {
            case PressedButton.play:
              await _handlerCallbacks!.play(const PlayRequest());
            case PressedButton.pause:
              await _handlerCallbacks!.pause(const PauseRequest());
            case PressedButton.next:
              await _handlerCallbacks!.skipToNext(const SkipToNextRequest());
            case PressedButton.previous:
              await _handlerCallbacks!.skipToPrevious(const SkipToPreviousRequest());
            case PressedButton.stop:
              await _handlerCallbacks!.stop(const StopRequest());
            case PressedButton.fastForward:
              await _handlerCallbacks!.fastForward(const FastForwardRequest());
            case PressedButton.rewind:
              await _handlerCallbacks!.rewind(const RewindRequest());
            default:
              break;
          }
        });
      } catch (e) {
        debugPrint("Error: $e");
      }
    });
  }

  @override
  Future<void> setState(SetStateRequest request) async {
    if (request.state.playing && !smtc.enabled) {
      await smtc.enableSmtc().then((value) => smtc.setPlaybackStatus(PlaybackStatus.playing));
    } else {
      await smtc.setPosition(request.state.updatePosition);
      await smtc.setPlaybackStatus(request.state.playing ? PlaybackStatus.playing : PlaybackStatus.paused);

      await smtc.setRepeatMode(switch (request.state.repeatMode) {
        AudioServiceRepeatModeMessage.none => RepeatMode.none,
        AudioServiceRepeatModeMessage.one => RepeatMode.track,
        AudioServiceRepeatModeMessage.all => RepeatMode.list,
        AudioServiceRepeatModeMessage.group => throw UnimplementedError(),
      });
      await smtc.setShuffleEnabled(switch (request.state.shuffleMode) {
        AudioServiceShuffleModeMessage.none => false,
        AudioServiceShuffleModeMessage.all => true,
        AudioServiceShuffleModeMessage.group => throw UnimplementedError(),
      });
    }
  }

  @override
  Future<void> setQueue(SetQueueRequest request) async {}

  @override
  Future<void> setMediaItem(SetMediaItemRequest request) async {
    var artURI = request.mediaItem.artUri;
    await smtc.updateMetadata(
      MusicMetadata(
        title: request.mediaItem.title,
        album: request.mediaItem.album,
        artist: request.mediaItem.artist,
        // We need a null, not the String "null"
        // ignore: prefer_null_aware_operators
        thumbnail: artURI == null ? null : artURI.toString(),
      ),
    );
    await smtc.setTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        minSeekTimeMs: 0,
        endTimeMs: request.mediaItem.duration?.inMilliseconds ?? 0,
        maxSeekTimeMs: request.mediaItem.duration?.inMilliseconds ?? 0,
        positionMs: 0,
      ),
    );
  }

  @override
  Future<void> stopService(StopServiceRequest request) async {
    await smtc.disableSmtc();
  }

  @override
  Future<void> notifyChildrenChanged(NotifyChildrenChangedRequest request) async {
    throw UnimplementedError('notifyChildrenChanged() has not been implemented.');
  }

  @override
  void setHandlerCallbacks(AudioHandlerCallbacks callbacks) {
    _handlerCallbacks = callbacks;
  }
}
