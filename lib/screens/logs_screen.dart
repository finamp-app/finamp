import 'package:finamp/components/LogsScreen/export_logs_button.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:flutter/material.dart';
import 'package:finamp/l10n/app_localizations.dart';

import '../components/LogsScreen/logs_view.dart';
import '../components/LogsScreen/share_logs_button.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  static const routeName = "/logs";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.logs),
        leading: FinampAppBarBackButton(),
        actions: const [
          ExportLogsButton(),
          ShareLogsButton(),
          // CopyLogsButton(), //!!! this doesn't return the full logs, only logs since the app started. Full logs can get quite large, so we need a better solution for this.
        ],
      ),
      body: const LogsView(),
    );
  }
}
