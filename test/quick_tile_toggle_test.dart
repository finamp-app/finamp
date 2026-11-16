import 'package:finamp/services/quick_tile_toggle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickTileToggle', () {
    late List<String> calls;
    late bool playing;
    late bool currentTrack;
    late Future<bool> Function() restore;
    late Future<void> Function() shuffle;

    QuickTileToggle createToggle() {
      return QuickTileToggle(
        isPlaying: () => playing,
        hasCurrentTrack: () => currentTrack,
        ensureQueueLoaded: () {
          calls.add('ensureQueueLoaded');
          return restore();
        },
        play: () async => calls.add('play'),
        pause: () async => calls.add('pause'),
        shuffleAll: () {
          calls.add('shuffleAll');
          return shuffle();
        },
      );
    }

    setUp(() {
      calls = [];
      playing = false;
      currentTrack = false;
      restore = () async => false;
      shuffle = () async {};
    });

    test('pauses when playing', () async {
      playing = true;
      currentTrack = true;

      await createToggle()();

      expect(calls, ['pause']);
    });

    test('resumes without restoring when paused with a current track', () async {
      currentTrack = true;

      await createToggle()();

      expect(calls, ['play']);
    });

    test('restores the saved queue and plays when there is no current track', () async {
      restore = () async => true;

      await createToggle()();

      expect(calls, ['ensureQueueLoaded', 'play']);
    });

    test('shuffles all when there is nothing to restore', () async {
      await createToggle()();

      expect(calls, ['ensureQueueLoaded', 'shuffleAll']);
    });

    test('shuffles all when restoring the queue fails', () async {
      restore = () async => throw Exception('restore failed');

      await createToggle()();

      expect(calls, ['ensureQueueLoaded', 'shuffleAll']);
    });

    test('does not throw when shuffle all fails', () async {
      shuffle = () async => throw Exception('shuffle failed');

      await expectLater(createToggle()(), completes);
      expect(calls, ['ensureQueueLoaded', 'shuffleAll']);
    });
  });
}
