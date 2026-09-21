import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tief_test_harness/tief_test_harness.dart';

import '../harness_creation.dart';
import '../jellyfin_helpers.dart';

@RegisterHarness("main", name: "Player Screen")
Future<ScenarioHarness> buildPlayerScreenHarness() async {
  final harness = createHarness();

  harness.addScenario(
    Scenario(
      name: "Main",
      testCallback: (tester, binding) async {
        await loginToJellyfin(tester);

        final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
        final playlist = await jellyfinApiHelper.getItemById(
          BaseItemId(const String.fromEnvironment("JELLYFIN_PLAYLIST_ID")),
        );
        final playlistItems = await jellyfinApiHelper.getItems(parentItem: playlist);
        await GetIt.instance<QueueService>().startPlayback(
          items: playlistItems!,
          source: QueueItemSource.fromBaseItem(playlist),
        );
        await tester.pumpAndSettle(Duration(seconds: 10));

        final nowPlayingBarFinder = find.byType(NowPlayingBar);
        await tester.tap(nowPlayingBarFinder);
        await tester.pumpAndSettle();
      },
    ),
  );

  harness.addScenario(
    Scenario(
      name: "Dark Queue",
      testCallback: (tester, binding) async {
        FinampSetters.setThemeMode(ThemeMode.dark);
        await loginToJellyfin(tester);

        final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
        final playlist = await jellyfinApiHelper.getItemById(
          BaseItemId(const String.fromEnvironment("JELLYFIN_PLAYLIST_ID")),
        );
        final playlistItems = await jellyfinApiHelper.getItems(parentItem: playlist);
        await GetIt.instance<QueueService>().startPlayback(
          items: playlistItems!,
          source: QueueItemSource.fromBaseItem(playlist),
        );
        await tester.pumpAndSettle(Duration(seconds: 1));

        final nowPlayingBarFinder = find.byType(NowPlayingBar);
        await tester.tap(nowPlayingBarFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text("Queue").first);

        await tester.pumpAndSettle();
      },
    ),
  );

  return harness;
}
