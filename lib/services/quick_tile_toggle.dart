import 'package:logging/logging.dart';

/// Quick Settings tile tap: pause, resume (restoring the saved queue), or shuffle all if nothing to resume (#1382).
class QuickTileToggle {
  QuickTileToggle({
    required this.isPlaying,
    required this.hasCurrentTrack,
    required this.ensureQueueLoaded,
    required this.play,
    required this.pause,
    required this.shuffleAll,
  });

  static final _logger = Logger("QuickTileToggle");

  final bool Function() isPlaying;
  final bool Function() hasCurrentTrack;
  final Future<bool> Function() ensureQueueLoaded;
  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() shuffleAll;

  Future<void> call() async {
    if (isPlaying()) {
      return pause();
    }
    if (hasCurrentTrack() || await _tryRestoreQueue()) {
      return play();
    }
    try {
      await shuffleAll();
    } catch (e, s) {
      _logger.severe("Shuffle all failed", e, s);
    }
  }

  Future<bool> _tryRestoreQueue() async {
    try {
      return await ensureQueueLoaded();
    } catch (e) {
      // A failed restore shouldn't leave the tile doing nothing.
      _logger.warning("Saved queue restore failed, falling back to shuffle all: $e");
      return false;
    }
  }
}
