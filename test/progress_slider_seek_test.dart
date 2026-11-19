import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/PlayerScreen/progress_slider.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

class FixtureCache extends Fake implements BaseCacheManager {}

class SlowSeekAudioHandler extends Fake implements MusicPlayerBackgroundTask {
  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(
    const MediaItem(id: 'track', title: 'Track', duration: Duration(minutes: 3)),
  );

  @override
  final BehaviorSubject<PlaybackState> playbackState = BehaviorSubject.seeded(
    PlaybackState(playing: true, processingState: AudioProcessingState.ready),
  );

  final seekFinished = Completer<void>();
  int seeks = 0;

  @override
  Future<void> seek(Duration position) {
    seeks++;
    return seekFinished.future;
  }
}

void main() {
  late SlowSeekAudioHandler audioHandler;
  late StreamSubscription<Duration> positionSubscription;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // ProgressSlider reads AudioService.position, which needs an initialized audio_service.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.client.methods'),
      (call) async => <String, dynamic>{},
    );
    await AudioService.init(builder: BaseAudioHandler.new, cacheManager: FixtureCache());
    // audio_service keeps its position timer after the last listener; start it outside the test's fake clock.
    positionSubscription = AudioService.position.listen((_) {});
  });

  tearDownAll(() => positionSubscription.cancel());

  setUp(() {
    audioHandler = SlowSeekAudioHandler();
    GetIt.instance.registerSingleton<MusicPlayerBackgroundTask>(audioHandler);
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('a seek that finishes after the slider is removed does not throw', (tester) async {
    final showSlider = ValueNotifier(true);
    addTearDown(showSlider.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showSlider,
              builder: (context, show, _) => show ? const ProgressSlider() : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pump();
    expect(audioHandler.seeks, 1);

    showSlider.value = false;
    await tester.pump();

    audioHandler.seekFinished.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
