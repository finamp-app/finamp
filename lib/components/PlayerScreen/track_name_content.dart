import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/PlayerScreen/album_chip.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_more.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart' as jellyfin_models;
import 'package:finamp/screens/player_screen.dart';
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

    final jellyfin_models.BaseItemDto trackBaseItemDto = currentTrack.baseItem;

    Widget getContent(BoxConstraints constraints, double padding) => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth - padding),
          child: Semantics.fromProperties(
            properties: SemanticsProperties(
              label: "${currentTrack.item.title} (${AppLocalizations.of(context)!.title})",
            ),
            excludeSemantics: true,
            container: true,
            child: Consumer(
              builder: (context, ref, _) {
                final text = currentTrack.item.title;
                final isTwoLineMode = controller.shouldShow(PlayerHideable.twoLineTitle);

                final textStyle = TextStyle(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: Theme.brightnessOf(context) == Brightness.light ? FontWeight.w500 : FontWeight.w500,
                );

                final textSpan = TextSpan(text: text, style: textStyle);
                // Showing two lines is probably better than one scrolling line, even if it clips
                final textPainter = TextPainter(
                  text: textSpan,
                  textDirection: TextDirection.ltr,
                  maxLines: isTwoLineMode ? 2 : 1,
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth - padding);

                final wouldOverflow = textPainter.didExceedMaxLines;
                textPainter.dispose();

                // Setting controls preference between marquee and two line clipped title.  If we only have one
                // line, always marquee.  TODO add another setting to disable this?
                if (wouldOverflow && (ref.watch(finampSettingsProvider.oneLineMarqueeTextButton) || !isTwoLineMode)) {
                  return SizedBox(
                    width: 280,
                    height: 12 + MediaQuery.textScalerOf(context).scale(18),
                    child: ScrollingTextHelper(
                      id: ValueKey(currentTrack.item.id),
                      text: text,
                      style: textStyle,
                      alignment: TextAlign.center,
                    ),
                  );
                } else if (isTwoLineMode) {
                  return SizedBox(
                    height: 4.0 + 2.4 * MediaQuery.textScalerOf(context).scale(18),
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
                } else {
                  return Text(
                    text,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  );
                }
              },
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlayerButtonsMore(
              item: trackBaseItemDto,
              queueItem: currentTrack,
              showHiddenPlayerActions: !controller.shouldShow(PlayerHideable.bottomActions),
            ),
            Flexible(
              child: ArtistChips(
                baseItem: trackBaseItemDto,
                backgroundColor: IconTheme.of(context).color!.withValues(alpha: 0.1),
              ),
            ),
            AddToPlaylistButton(item: trackBaseItemDto, queueItem: currentTrack),
          ],
        ),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AlbumChips(
              baseItem: trackBaseItemDto,
              backgroundColor: IconTheme.of(context).color!.withValues(alpha: 0.1),
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
