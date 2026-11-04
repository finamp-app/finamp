import 'package:finamp/services/data_source_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canAutomaticallyReloadOfflineQueue', () {
    test('allows a loss equal to the configured percentage', () {
      expect(
        canAutomaticallyReloadOfflineQueue(trackCount: 10, undownloadedTracks: 3, maximumDroppedTracksPercentage: 30),
        isTrue,
      );
    });

    test('blocks a loss above the configured percentage', () {
      expect(
        canAutomaticallyReloadOfflineQueue(trackCount: 10, undownloadedTracks: 4, maximumDroppedTracksPercentage: 30),
        isFalse,
      );
    });

    test('supports the strict and always-reload endpoints', () {
      expect(
        canAutomaticallyReloadOfflineQueue(trackCount: 10, undownloadedTracks: 1, maximumDroppedTracksPercentage: 0),
        isFalse,
      );
      expect(
        canAutomaticallyReloadOfflineQueue(trackCount: 10, undownloadedTracks: 10, maximumDroppedTracksPercentage: 100),
        isTrue,
      );
    });

    test('rounds a non-whole loss percentage up for the warning', () {
      expect(offlineQueueLossPercentage(trackCount: 10, undownloadedTracks: 3), 30);
      expect(offlineQueueLossPercentage(trackCount: 3, undownloadedTracks: 1), 34);
    });
  });

  group('decideNetworkQueueReloadAction', () {
    test('shows a manual reload prompt when the offline loss exceeds the limit', () {
      expect(
        decideNetworkQueueReloadAction(
          autoReloadQueue: true,
          event: SourceChangeType.toOffline,
          trackCount: 10,
          undownloadedTracks: 4,
          maximumDroppedTracksPercentage: 30,
        ),
        NetworkQueueReloadAction.manualPrompt,
      );
    });

    test('reloads automatically when the offline loss is within the limit', () {
      expect(
        decideNetworkQueueReloadAction(
          autoReloadQueue: true,
          event: SourceChangeType.toOffline,
          trackCount: 10,
          undownloadedTracks: 3,
          maximumDroppedTracksPercentage: 30,
        ),
        NetworkQueueReloadAction.automatic,
      );
    });

    test('keeps the existing manual prompt when automatic reload is disabled', () {
      expect(
        decideNetworkQueueReloadAction(
          autoReloadQueue: false,
          event: SourceChangeType.toRemoteUrl,
          trackCount: 10,
          undownloadedTracks: 1,
          maximumDroppedTracksPercentage: 30,
        ),
        NetworkQueueReloadAction.manualPrompt,
      );
    });
  });

  group('shouldShowAutoOfflineNotification', () {
    test('keeps the actionable queue prompt visible when entering offline mode', () {
      expect(
        shouldShowAutoOfflineNotification(isOffline: true, queueReloadAction: NetworkQueueReloadAction.manualPrompt),
        isFalse,
      );
    });

    test('keeps the generic notification for automatic reloads and when returning online', () {
      expect(
        shouldShowAutoOfflineNotification(isOffline: true, queueReloadAction: NetworkQueueReloadAction.automatic),
        isTrue,
      );
      expect(
        shouldShowAutoOfflineNotification(isOffline: false, queueReloadAction: NetworkQueueReloadAction.manualPrompt),
        isTrue,
      );
    });
  });

  group('shouldReloadQueueForUrlChange', () {
    test('keeps the current queue during an offline URL hand-off', () {
      expect(shouldReloadQueueForUrlChange(isOffline: true), isFalse);
    });

    test('reloads for a URL change while online', () {
      expect(shouldReloadQueueForUrlChange(isOffline: false), isTrue);
    });
  });
}
