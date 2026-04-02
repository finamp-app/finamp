import 'package:finamp/components/AudiobookScreen/audiobook_screen_content.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/chapter_extractor_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';

import '../models/finamp_models.dart';

class AudiobookScreen extends StatefulWidget {
  const AudiobookScreen({super.key, this.parent});

  static const routeName = "/music/audiobook";

  /// The audiobook to show. Can also be provided as a route argument.
  final BaseItemDto? parent;

  @override
  State<AudiobookScreen> createState() => _AudiobookScreenState();
}

class _AudiobookScreenState extends State<AudiobookScreen> {
  Future<List<BaseItemDto>?>? _chaptersFuture;
  // For single-file AudioBook items: extract chapters directly from the .m4b
  // file stream via native AVFoundation — Jellyfin doesn't return chapter data
  // for AudioBook items even with the Chapters field requested.
  Future<List<ChapterInfo>>? _embeddedChaptersFuture;
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  @override
  Widget build(BuildContext context) {
    final BaseItemDto parent = widget.parent ??
        ModalRoute.of(context)!.settings.arguments as BaseItemDto;

    return Scaffold(
      extendBody: true,
      body: ValueListenableBuilder<Box<FinampSettings>>(
        valueListenable: FinampSettingsHelper.finampSettingsListener,
        builder: (context, box, _) {
          final isOffline = box.get("FinampSettings")?.isOffline ?? false;

          if (isOffline) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(parent.name ??
                      AppLocalizations.of(context)!.unknownName),
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.notAvailableInOfflineMode,
                    ),
                  ),
                ),
              ],
            );
          }

          // Jellyfin's AudioBook items are single-file books (.m4b etc).
          // Jellyfin doesn't return chapter data via its API for AudioBook
          // items, so we extract them directly from the .m4b file stream
          // via native AVFoundation.
          if (parent.type == "AudioBook") {
            _embeddedChaptersFuture ??=
                ChapterExtractorService.extractChapters(parent.id.raw);
            return FutureBuilder<List<ChapterInfo>>(
              future: _embeddedChaptersFuture,
              builder: (context, snapshot) {
                return AudiobookScreenContent(
                  parent: parent,
                  chapters: [parent],
                  embeddedChapters: snapshot.data,
                );
              },
            );
          }

          // For any container type (e.g. legacy folder-based books) fetch
          // child Audio/AudioBook tracks from the server.
          _chaptersFuture ??= _jellyfinApiHelper.getItems(
            parentItem: parent,
            sortBy: "ParentIndexNumber,IndexNumber,SortName",
            includeItemTypes: "Audio,AudioBook",
          );

          return FutureBuilder<List<BaseItemDto>?>(
            future: _chaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final chapters =
                    snapshot.data!.isEmpty ? [parent] : snapshot.data!;
                return AudiobookScreenContent(
                  parent: parent,
                  chapters: chapters,
                );
              } else if (snapshot.hasError) {
                return CustomScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      title: Text(AppLocalizations.of(context)!.error),
                    ),
                    SliverFillRemaining(
                      child: Center(child: Text(snapshot.error.toString())),
                    ),
                  ],
                );
              } else {
                return CustomScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      title: Text(parent.name ??
                          AppLocalizations.of(context)!.unknownName),
                    ),
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                  ],
                );
              }
            },
          );
        },
      ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}
