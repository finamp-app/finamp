import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../components/QueueRestoreScreen/queue_restore_tile.dart';
import '../services/queue_service.dart';

class QueueRestoreScreen extends StatelessWidget {
  const QueueRestoreScreen({super.key});

  static const routeName = "/queues";

  @override
  Widget build(BuildContext context) {
    final queueList = GetIt.instance<QueueService>().getRecentQueueHistory();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.queuesScreen), leading: FinampAppBarBackButton()),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 10.0, bottom: 200.0),
        itemCount: queueList.length,
        itemBuilder: (context, index) {
          return QueueRestoreTile(key: ValueKey(queueList.elementAt(index).creation), info: queueList.elementAt(index));
        },
      ),
    );
  }
}
