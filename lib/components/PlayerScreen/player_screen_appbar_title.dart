import 'package:balanced_text/balanced_text.dart';
import 'package:finamp/components/PlayerScreen/queue_source_helper.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../extensions/localizations.dart';

class PlayerScreenAppBarTitle extends StatefulWidget {
  const PlayerScreenAppBarTitle({super.key, required this.maxLines});

  final int maxLines;

  @override
  State<PlayerScreenAppBarTitle> createState() => _PlayerScreenAppBarTitleState();
}

class _PlayerScreenAppBarTitleState extends State<PlayerScreenAppBarTitle> {
  final QueueService _queueService = GetIt.instance<QueueService>();

  @override
  Widget build(BuildContext context) {
    final currentTrackStream = _queueService.getCurrentTrackStream();

    final screenWidth = MediaQuery.widthOf(context);

    return StreamBuilder<FinampQueueItem?>(
      stream: currentTrackStream,
      initialData: _queueService.getCurrentTrack(),
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final queueItem = snapshot.data!;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenWidth * 0.62),
          child: GestureDetector(
            onTap: () => navigateToSource(context, queueItem.source),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.playingFromType(queueItem.source.type.name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Theme.brightnessOf(context) == Brightness.dark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 1)),
                BalancedText(
                  queueItem.source.name.getLocalized(context.l10n),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.brightnessOf(context) == Brightness.dark
                        ? Colors.white
                        : Colors.black.withOpacity(0.9),
                  ),
                  maxLines: widget.maxLines,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
