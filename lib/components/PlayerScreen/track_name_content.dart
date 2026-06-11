import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/PlayerScreen/album_chip.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_more.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart' as jellyfin_models;
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/services/current_album_image_provider.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/scrolling_text_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackNameContent extends ConsumerWidget {
  const TrackNameContent(this.controller, {super.key});

  final PlayerHideableController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(QueueService.queueProvider);

    if (queue?.currentTrack == null) {
      return const CircularProgressIndicator();
    }
    final currentTrack = queue!.currentTrack!;

    // While controlling a remote session, mirror its now-playing item instead
    // of the local queue's track (Play On, Slice D3b). Queue-bound actions get
    // a null queueItem then: the remote track has no local queue item.
    final remoteItem = ref.watch(remoteNowPlayingItemProvider).valueOrNull;
    final jellyfin_models.BaseItemDto trackBaseItemDto = remoteItem ?? currentTrack.baseItem;
    final queueItem = remoteItem == null ? currentTrack : null;
    final title = remoteItem == null ? currentTrack.item.title : remoteItem.name ?? currentTrack.item.title;

    Widget getContent(BoxConstraints constraints, double padding) => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth - padding),
          child: Semantics.fromProperties(
            properties: SemanticsProperties(
              label: "$title (${AppLocalizations.of(context)!.title})",
            ),
            excludeSemantics: true,
            container: true,
            child: Consumer(
              builder: (context, ref, _) {
                final text = title;
                final isTwoLineMode = controller.shouldShow(PlayerHideable.twoLineTitle);

                final textStyle = TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: Theme.brightnessOf(context) == Brightness.light ? FontWeight.w500 : FontWeight.w500,
                );

                final textSpan = TextSpan(text: text, style: textStyle);
                final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, maxLines: 2)
                  ..layout(maxWidth: 280);

                final wouldOverflow = textPainter.didExceedMaxLines;
                textPainter.dispose();

                if (!isTwoLineMode) {
                  return Text(
                    text,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  );
                } else {
                  if (wouldOverflow && ref.watch(finampSettingsProvider.oneLineMarqueeTextButton)) {
                    return SizedBox(
                      width: 280,
                      height: 30,
                      child: ScrollingTextHelper(
                        id: ValueKey(remoteItem?.id.raw ?? currentTrack.item.id),
                        text: text,
                        style: textStyle,
                        alignment: TextAlign.center,
                      ),
                    );
                  } else {
                    return SizedBox(
                      height: 48.0,
                      child: Center(
                        child: Text(
                          text,
                          style: textStyle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlayerButtonsMore(item: trackBaseItemDto, queueItem: queueItem),
            Flexible(
              child: ArtistChips(
                baseItem: trackBaseItemDto,
                backgroundColor: IconTheme.of(context).color!.withOpacity(0.1),
              ),
            ),
            AddToPlaylistButton(item: trackBaseItemDto, queueItem: queueItem),
          ],
        ),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AlbumChips(
              baseItem: trackBaseItemDto,
              backgroundColor: IconTheme.of(context).color!.withOpacity(0.1),
              key: trackBaseItemDto.album == null ? null : ValueKey("${trackBaseItemDto.album}-album"),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        double padding = ((constraints.maxWidth - 260) / 4).clamp(0, 20);
        return Padding(
          padding: EdgeInsets.only(left: padding, right: padding, bottom: 4.0),
          child: getContent(constraints, padding),
        );
      },
    );
  }
}
