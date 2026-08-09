import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../components/QueueRestoreScreen/queue_restore_tile.dart';
import '../models/finamp_models.dart';

class QueueRestoreScreen extends StatelessWidget {
  const QueueRestoreScreen({super.key});

  static const routeName = "/queues";

  @override
  Widget build(BuildContext context) {
    final queuesBox = Hive.box<FinampStorableQueueInfo>("Queues");
    var queueMap = queuesBox.toMap();
    queueMap.remove("latest");
    var queueList = queueMap.values.toList();
    queueList.sort((x, y) => y.creation - x.creation);

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
