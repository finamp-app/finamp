import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../models/finamp_models.dart';
import '../../services/finamp_settings_helper.dart';

class ActiveNetworkDisplay extends ConsumerWidget {
  const ActiveNetworkDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? address = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.baseURL;

    return ValueListenableBuilder<Box<FinampSettings>>(
      valueListenable: FinampSettingsHelper.finampSettingsListener,
      builder: (context, box, __) {
        return ListTile(
          leading: Icon(Icons.router_outlined),
          title: Text(AppLocalizations.of(context)!.preferLocalNetworkActiveAddressInfoText),
          subtitle: Text(address ?? ""),
          subtitleTextStyle: TextTheme.of(context).bodySmall,
        );
      },
    );
  }
}
