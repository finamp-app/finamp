import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class LocalNetworkSelector extends ConsumerWidget {
  const LocalNetworkSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool preferLocalNetwork =
        ref.watch(FinampUserHelper.finampCurrentUserProvider)?.preferLocalNetwork ?? DefaultSettings.preferLocalNetwork;

    return SwitchListTile.adaptive(
      title: Text(AppLocalizations.of(context)!.preferLocalNetworkEnableSwitchTitle),
      subtitle: Text(AppLocalizations.of(context)!.preferLocalNetworkEnableSwitchDescription),
      value: preferLocalNetwork,
      onChanged: (value) async {
        GetIt.instance<FinampUserHelper>().currentUser?.update(newPreferLocalNetwork: value);
        await changeTargetUrl();
      },
    );
  }
}
