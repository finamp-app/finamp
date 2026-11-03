import 'dart:async';

import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Gives a useful next step without treating missing UDP replies as proof that
/// the server is offline. Discovery itself continues to accept late replies.
class ServerDiscoveryStatus extends StatefulWidget {
  const ServerDiscoveryStatus({super.key, required this.hasServers});

  final bool hasServers;

  @override
  State<ServerDiscoveryStatus> createState() => _ServerDiscoveryStatusState();
}

class _ServerDiscoveryStatusState extends State<ServerDiscoveryStatus> {
  late final Timer _hintTimer;
  bool _initialWaitComplete = false;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(seconds: 8), () {
      setState(() => _initialWaitComplete = true);
    });
  }

  @override
  void dispose() {
    _hintTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(4.0),
              child: SizedBox(height: 20.0, width: 20.0, child: CircularProgressIndicator(strokeWidth: 2.0)),
            ),
            const SizedBox(width: 8.0),
            Flexible(child: Text(strings.loginFlowLocalNetworkServersScanningForServers, style: style)),
          ],
        ),
        if (_initialWaitComplete && !widget.hasServers)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(strings.loginFlowLocalNetworkServersNoResults, textAlign: TextAlign.center, style: style),
          ),
      ],
    );
  }
}
